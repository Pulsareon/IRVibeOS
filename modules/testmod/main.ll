; IRVibeOS testmod module.
; A minimal runnable module used by the hosted shell app registry.

@msg = private unnamed_addr constant [27 x i8] c"testmod module is runnable\00"

declare i32 @puts(ptr)

define i32 @main() {
entry:
  call i32 @puts(ptr @msg)
  ret i32 0
}
