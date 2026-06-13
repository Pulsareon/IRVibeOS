; Pattern: RAM boundary probing
; 模式：RAM 边界探测
;
; Strategy: write a known value to an address, read it back.
; 策略：向地址写入已知值，再读回来比较。
; If the readback matches, that address is valid RAM.
; 如果读回值匹配，则该地址是有效 RAM。
; Binary search to find the upper boundary.
; 可用二分法找到上边界。
;
; Useful when AI doesn't know device RAM size.
; 当 AI 不知道设备 RAM 大小时使用。
; Start from a known base (e.g., 0x20000000 on Cortex-M) and probe upward.
; 从已知基地址开始（如 Cortex-M 的 0x20000000）向上探测。

; Probe a single address: returns 1 if writable RAM, 0 if not
; 探测单个地址：可写 RAM 返回 1，否则返回 0
define i32 @probe_address(i64 %addr) {
entry:
  %ptr = inttoptr i64 %addr to ptr
  ; Write a test pattern
  store volatile i32 305419896, ptr %ptr     ; 0x12345678
  ; Read it back
  %readback = load volatile i32, ptr %ptr
  %match = icmp eq i32 %readback, 305419896
  %result = zext i1 %match to i32
  ret i32 %result
}

; Find the end of RAM starting from base_addr, stepping by step_size.
; 从 base_addr 开始，以 step_size 为步长，找到 RAM 末尾。
; Returns the last valid address found.
; 返回找到的最后一个有效地址。
define i64 @find_ram_end(i64 %base_addr, i64 %step_size) {
entry:
  br label %loop

loop:
  %addr = phi i64 [%base_addr, %entry], [%next_addr, %continue]
  %valid = call i32 @probe_address(i64 %addr)
  %is_valid = icmp eq i32 %valid, 1
  br i1 %is_valid, label %continue, label %done

continue:
  %next_addr = add i64 %addr, %step_size
  br label %loop

done:
  %last_valid = sub i64 %addr, %step_size
  ret i64 %last_valid
}
