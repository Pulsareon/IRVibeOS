; 我的第一个IRVibeOS模块
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

@.greeting = private constant [26 x i8] c"Hello from my IR module!\0A\00"

declare i32 @printf(ptr, ...)

define i32 @main() {
entry:
  %result = call i32 @printf(ptr @.greeting)
  ret i32 0
}
