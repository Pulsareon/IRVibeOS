; Pattern: RAM boundary probing
;
; Strategy: write a known value to an address, read it back.
; If the readback matches, that address is valid RAM.
; Binary search to find the upper boundary.
;
; This is useful when the AI doesn't know how much RAM a device has.
; Start from a known base (e.g., 0x20000000 on Cortex-M) and probe upward.

; Probe a single address: returns 1 if writable RAM, 0 if not
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
; Returns the last valid address found.
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
