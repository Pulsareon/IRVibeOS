; Example LLVM IR module. Examples are IR too.

@msg = private unnamed_addr constant [27 x i8] c"example hello from LLVM IR\00"

declare i32 @puts(ptr)

define i32 @main() {
entry:
  call i32 @puts(ptr @msg)
  ret i32 0
}
