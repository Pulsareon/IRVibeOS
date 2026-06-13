; Dynamic IRVibeOS module: hello.

@msg = private unnamed_addr constant [32 x i8] c"hello module loaded dynamically\00"

declare i32 @puts(ptr)

define i32 @main() {
entry:
  call i32 @puts(ptr @msg)
  ret i32 0
}
