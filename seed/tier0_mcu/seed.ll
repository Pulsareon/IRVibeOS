; IRVibeOS Seed — platform-independent main loop.
; IRVibeOS 种子 — 平台无关主循环。
;
; This is the irreducible kernel. It receives code, places it, and jumps to it.
; 这是不可再减的内核。它接收代码、放入内存、跳转执行。
;
; Platform must provide / 平台必须实现:
;   @seed_recv_byte() -> i8    ; receive one byte / 接收一个字节
;   @seed_send_byte(i8) -> void ; send one byte / 发送一个字节
;
; Protocol (TALK) / 协议:
;   Each message framed by sync word 0xAA 0x55.
;   每条消息以同步字 0xAA 0x55 开头。
;
;   Opcodes / 操作码:
;     0x01 = EXEC  [4B len][payload]        → execute as () -> i32 / 执行并返回 i32
;     0x02 = PEEK  [8B addr][4B len]        → read memory / 读内存
;     0x03 = POKE  [8B addr][4B len][data]  → write memory / 写内存
;     0x04 = INFO  []                       → device descriptor / 设备描述
;
;   Response / 响应: [0xAA 0x55][1B status][4B len][data]
;     status 0x00 = OK / 成功
;     status 0xFE = unknown opcode / 未知操作码
;
;   On desync, receiver scans for next 0xAA 0x55.
;   失步时，接收方扫描下一个 0xAA 0x55。

; --- Executable memory slot / 可执行内存槽 ---
; Size conservative for small MCUs; override via platform link.
; 大小保守适配小型 MCU；可通过平台链接覆盖。
@code_slot = global [4096 x i8] zeroinitializer, align 16
@code_slot_size = weak global i32 4096

; Device identity (override per platform) / 设备标识（各平台可覆盖）
@device_info = weak global [32 x i8] c"irvibeos-seed-generic\00\00\00\00\00\00\00\00\00\00\00"

; --- Platform I/O / 平台 I/O ---
declare i8   @seed_recv_byte()
declare void @seed_send_byte(i8)

; --- LLVM intrinsic: flush I-cache / 刷新指令缓存 ---
declare void @llvm.clear_cache(ptr, ptr)

define i32 @main() {
entry:
  br label %sync

; Scan for sync word 0xAA 0x55 / 扫描同步字
sync:
  %s0 = call i8 @seed_recv_byte()
  %is_aa = icmp eq i8 %s0, -86          ; 0xAA
  br i1 %is_aa, label %sync_55, label %sync

sync_55:
  %s1 = call i8 @seed_recv_byte()
  %is_55 = icmp eq i8 %s1, 85           ; 0x55
  br i1 %is_55, label %dispatch, label %sync

; Read opcode and dispatch / 读取操作码并分派
dispatch:
  %opcode = call i8 @seed_recv_byte()
  switch i8 %opcode, label %unknown [
    i8 1, label %do_exec
    i8 2, label %do_peek
    i8 3, label %do_poke
    i8 4, label %do_info
  ]

; EXEC: receive code, flush cache, call / 接收代码、刷缓存、调用
do_exec:
  %exec_len = call i32 @recv_u32()
  ; Clamp to slot capacity / 钳位到槽容量
  %slot_cap = load i32, ptr @code_slot_size
  %len_ok = icmp ule i32 %exec_len, %slot_cap
  %safe_len = select i1 %len_ok, i32 %exec_len, i32 %slot_cap
  ; Volatile stores prevent optimizer elimination / volatile 写入防止优化器消除
  call void @recv_bytes_volatile(ptr @code_slot, i32 %safe_len)
  ; Memory barrier + I-cache invalidation / 内存屏障 + 指令缓存失效
  fence seq_cst
  %slot_end = getelementptr i8, ptr @code_slot, i32 %safe_len
  call void @llvm.clear_cache(ptr @code_slot, ptr %slot_end)
  ; Execute / 执行
  %result = call i32 @code_slot()
  ; Reply / 回复
  call void @send_sync()
  call void @seed_send_byte(i8 0)
  call void @send_u32(i32 4)
  call void @send_u32(i32 %result)
  br label %sync

; PEEK: read memory / 读内存
do_peek:
  %peek_addr = call i64 @recv_u64()
  %peek_len = call i32 @recv_u32()
  %peek_ptr = inttoptr i64 %peek_addr to ptr
  call void @send_sync()
  call void @seed_send_byte(i8 0)
  call void @send_u32(i32 %peek_len)
  call void @send_bytes(ptr %peek_ptr, i32 %peek_len)
  br label %sync

; POKE: write memory / 写内存
do_poke:
  %poke_addr = call i64 @recv_u64()
  %poke_len = call i32 @recv_u32()
  %poke_ptr = inttoptr i64 %poke_addr to ptr
  call void @recv_bytes(ptr %poke_ptr, i32 %poke_len)
  call void @send_sync()
  call void @seed_send_byte(i8 0)
  call void @send_u32(i32 0)
  br label %sync

; INFO: report identity and capabilities / 报告设备身份和能力
do_info:
  call void @send_sync()
  call void @seed_send_byte(i8 0)
  call void @send_u32(i32 36)
  call void @send_bytes(ptr @device_info, i32 32)
  %info_cap = load i32, ptr @code_slot_size
  call void @send_u32(i32 %info_cap)
  br label %sync

; Unknown opcode / 未知操作码
unknown:
  call void @send_sync()
  call void @seed_send_byte(i8 -2)       ; 0xFE
  call void @send_u32(i32 0)
  br label %sync
}

; ============================================================
; Helpers / 辅助函数
; ============================================================

; Send sync word / 发送同步字
define void @send_sync() {
entry:
  call void @seed_send_byte(i8 -86)      ; 0xAA
  call void @seed_send_byte(i8 85)       ; 0x55
  ret void
}

; Receive little-endian u32 / 接收小端序 u32
define i32 @recv_u32() {
entry:
  %b0 = call i8 @seed_recv_byte()
  %b1 = call i8 @seed_recv_byte()
  %b2 = call i8 @seed_recv_byte()
  %b3 = call i8 @seed_recv_byte()
  %v0 = zext i8 %b0 to i32
  %v1 = zext i8 %b1 to i32
  %v2 = zext i8 %b2 to i32
  %v3 = zext i8 %b3 to i32
  %s1 = shl i32 %v1, 8
  %s2 = shl i32 %v2, 16
  %s3 = shl i32 %v3, 24
  %r1 = or i32 %v0, %s1
  %r2 = or i32 %r1, %s2
  %r3 = or i32 %r2, %s3
  ret i32 %r3
}

; Receive little-endian u64 / 接收小端序 u64
define i64 @recv_u64() {
entry:
  %lo = call i32 @recv_u32()
  %hi = call i32 @recv_u32()
  %lo64 = zext i32 %lo to i64
  %hi64 = zext i32 %hi to i64
  %hi_s = shl i64 %hi64, 32
  %val = or i64 %lo64, %hi_s
  ret i64 %val
}

; Send little-endian u32 / 发送小端序 u32
define void @send_u32(i32 %val) {
entry:
  %b0 = trunc i32 %val to i8
  %v1 = lshr i32 %val, 8
  %b1 = trunc i32 %v1 to i8
  %v2 = lshr i32 %val, 16
  %b2 = trunc i32 %v2 to i8
  %v3 = lshr i32 %val, 24
  %b3 = trunc i32 %v3 to i8
  call void @seed_send_byte(i8 %b0)
  call void @seed_send_byte(i8 %b1)
  call void @seed_send_byte(i8 %b2)
  call void @seed_send_byte(i8 %b3)
  ret void
}

; Receive N bytes — normal stores (for data) / 接收 N 字节 — 普通写入（数据用）
define void @recv_bytes(ptr %buf, i32 %len) {
entry:
  %has = icmp ugt i32 %len, 0
  br i1 %has, label %loop, label %done

loop:
  %i = phi i32 [0, %entry], [%next, %loop]
  %byte = call i8 @seed_recv_byte()
  %p = getelementptr i8, ptr %buf, i32 %i
  store i8 %byte, ptr %p
  %next = add i32 %i, 1
  %more = icmp ult i32 %next, %len
  br i1 %more, label %loop, label %done

done:
  ret void
}

; Receive N bytes — volatile stores (for code) / 接收 N 字节 — volatile 写入（代码用）
define void @recv_bytes_volatile(ptr %buf, i32 %len) {
entry:
  %has = icmp ugt i32 %len, 0
  br i1 %has, label %loop, label %done

loop:
  %i = phi i32 [0, %entry], [%next, %loop]
  %byte = call i8 @seed_recv_byte()
  %p = getelementptr i8, ptr %buf, i32 %i
  store volatile i8 %byte, ptr %p
  %next = add i32 %i, 1
  %more = icmp ult i32 %next, %len
  br i1 %more, label %loop, label %done

done:
  ret void
}

; Send N bytes from buffer / 从缓冲区发送 N 字节
define void @send_bytes(ptr %buf, i32 %len) {
entry:
  %has = icmp ugt i32 %len, 0
  br i1 %has, label %loop, label %done

loop:
  %i = phi i32 [0, %entry], [%next, %loop]
  %p = getelementptr i8, ptr %buf, i32 %i
  %byte = load i8, ptr %p
  call void @seed_send_byte(i8 %byte)
  %next = add i32 %i, 1
  %more = icmp ult i32 %next, %len
  br i1 %more, label %loop, label %done

done:
  ret void
}
