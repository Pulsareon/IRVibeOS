; IRVibeOS Seed — hosted platform (stdin/stdout).
; For development and testing on a PC.
; Link with tier0_mcu/seed.ll:
;   llvm-link seed/tier0_mcu/seed.ll seed/tier3_hosted/seed.ll -o build/seed.bc
;   lli build/seed.bc
;
; Provides seed_recv_byte and seed_send_byte via libc.
; NOTE: stdin should be in binary mode for correct protocol operation.

declare i32 @getchar()
declare i32 @putchar(i32)
declare i32 @fflush(ptr)
declare void @exit(i32)

; Override device info for hosted mode
@device_info = global [32 x i8] c"irvibeos-seed-hosted\00\00\00\00\00\00\00\00\00\00\00\00"

; Hosted mode can afford a larger code slot
@code_slot_size = global i32 65536

define i8 @seed_recv_byte() {
entry:
  %ch = call i32 @getchar()
  ; getchar returns -1 on EOF — exit cleanly
  %is_eof = icmp eq i32 %ch, -1
  br i1 %is_eof, label %eof, label %ok

eof:
  call void @exit(i32 0)
  unreachable

ok:
  %byte = trunc i32 %ch to i8
  ret i8 %byte
}

define void @seed_send_byte(i8 %byte) {
entry:
  %val = zext i8 %byte to i32
  call i32 @putchar(i32 %val)
  call i32 @fflush(ptr null)
  ret void
}
