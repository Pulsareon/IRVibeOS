; IRVibeOS Seed — hosted platform (stdin/stdout).
; IRVibeOS 种子 — 宿主平台（标准输入/输出）。
;
; For development and testing on a PC.
; 用于 PC 上的开发和测试。
;
; Link with tier0_mcu/seed.ll / 与 tier0 种子链接:
;   llvm-link seed/tier0_mcu/seed.ll seed/tier3_hosted/seed.ll -o build/seed.bc
;   lli build/seed.bc
;
; Provides seed_recv_byte and seed_send_byte via libc.
; 通过 libc 提供 seed_recv_byte 和 seed_send_byte。
;
; NOTE: stdin should be in binary mode for correct protocol operation.
; 注意：stdin 应为二进制模式以确保协议正确运作。

declare i32 @getchar()
declare i32 @putchar(i32)
declare i32 @fflush(ptr)
declare void @exit(i32)

; Override device info for hosted mode / 宿主模式覆盖设备标识
@device_info = global [32 x i8] c"irvibeos-seed-hosted\00\00\00\00\00\00\00\00\00\00\00\00"

; Hosted mode can afford a larger code slot / 宿主模式可用更大的代码槽
@code_slot_size = global i32 65536

; Receive one byte from stdin / 从标准输入接收一个字节
; Returns the byte, or exits on EOF / 返回该字节，遇到 EOF 时退出
define i8 @seed_recv_byte() {
entry:
  %ch = call i32 @getchar()
  ; getchar returns -1 on EOF / getchar 在 EOF 时返回 -1
  %is_eof = icmp eq i32 %ch, -1
  br i1 %is_eof, label %eof, label %ok

eof:
  call void @exit(i32 0)
  unreachable

ok:
  %byte = trunc i32 %ch to i8
  ret i8 %byte
}

; Send one byte to stdout / 向标准输出发送一个字节
define void @seed_send_byte(i8 %byte) {
entry:
  %val = zext i8 %byte to i32
  call i32 @putchar(i32 %val)
  call i32 @fflush(ptr null)
  ret void
}
