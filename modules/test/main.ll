; IRVibeOS test module.
; Mirrors the first user-created module using the standard module entry path.

@msg = private unnamed_addr constant [25 x i8] c"Hello from my IR module!\00"

declare i32 @puts(ptr)

define i32 @main() {
entry:
  call i32 @puts(ptr @msg)
  ret i32 0
}
