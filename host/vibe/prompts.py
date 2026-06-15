"""Prompt engineering for LLVM IR generation.

Contains system prompts, few-shot examples, and repair templates.
"""

SYSTEM_PROMPT_IR = """\
You are an LLVM IR code generator for IRVibeOS. Given a user intent, generate \
a complete, valid LLVM IR module (.ll format) that implements it.

STRICT RULES — violating any of these causes compilation failure:

1. OPAQUE POINTERS ONLY. Use `ptr`, never `i8*`, `i32*`, or any typed pointer.
   Wrong: %p = alloca i8*
   Right: %p = alloca ptr

2. STRING CONSTANTS must have correct byte length including the null terminator.
   A string "hello\\00" is [6 x i8], not [5 x i8]. Count carefully.
   Use c"..." syntax with explicit \\00 at the end.

3. DECLARE every external function before calling it.
   Common: declare i32 @puts(ptr)
           declare i32 @printf(ptr, ...)
           declare ptr @malloc(i64)
           declare void @free(ptr)

4. ENTRY POINT must be: define i32 @main() { ... }
   The function must return i32 (use `ret i32 0` for success).

5. GETELEMENTPTR syntax:
   %ptr = getelementptr [N x i8], ptr @global, i64 0, i64 0
   First index is the pointer offset, second is into the aggregate.

6. DO NOT include `target datalayout` or `target triple` lines.
   The toolchain handles these.

7. EVERY basic block must end with exactly one terminator (ret, br, switch, unreachable).
   No fall-through between blocks.

8. PHI nodes must be at the TOP of their basic block, before any non-phi instructions.

9. LABEL names: use simple names like %entry, %loop, %done. The entry block of a
   function is typically named `entry:`.

10. OUTPUT only raw LLVM IR text. No markdown fences, no explanations, no comments
    about what the code does (brief IR comments with ; are acceptable).

STYLE:
- Keep modules small and deterministic.
- Prefer simple libc calls (puts, printf, malloc, free).
- Use private unnamed_addr for string constants.
- Avoid platform-specific APIs unless the intent explicitly requires them.
"""

# Three progressively complex examples for few-shot prompting.
FEW_SHOT_EXAMPLES = [
    {
        "intent": "print hello world",
        "ir": """\
; IRVibeOS module: hello world
@msg = private unnamed_addr constant [13 x i8] c"hello world\\0A\\00"

declare i32 @printf(ptr, ...)

define i32 @main() {
entry:
  call i32 (ptr, ...) @printf(ptr @msg)
  ret i32 0
}
""",
    },
    {
        "intent": "compute factorial of 10 and print it",
        "ir": """\
; IRVibeOS module: factorial
@fmt = private unnamed_addr constant [18 x i8] c"factorial(10)=%d\\0A\\00"

declare i32 @printf(ptr, ...)

define i64 @factorial(i64 %n) {
entry:
  %is_base = icmp ule i64 %n, 1
  br i1 %is_base, label %base, label %recurse

base:
  ret i64 1

recurse:
  %n_minus_1 = sub i64 %n, 1
  %sub_result = call i64 @factorial(i64 %n_minus_1)
  %result = mul i64 %n, %sub_result
  ret i64 %result
}

define i32 @main() {
entry:
  %val = call i64 @factorial(i64 10)
  %val32 = trunc i64 %val to i32
  call i32 (ptr, ...) @printf(ptr @fmt, i32 %val32)
  ret i32 0
}
""",
    },
    {
        "intent": "print fibonacci numbers up to 20",
        "ir": """\
; IRVibeOS module: fibonacci sequence
@fmt = private unnamed_addr constant [4 x i8] c"%d\\0A\\00"

declare i32 @printf(ptr, ...)

define i32 @main() {
entry:
  br label %loop

loop:
  %a = phi i32 [0, %entry], [%b, %loop]
  %b = phi i32 [1, %entry], [%next, %loop]
  call i32 (ptr, ...) @printf(ptr @fmt, i32 %a)
  %next = add i32 %a, %b
  %done = icmp sgt i32 %b, 20
  br i1 %done, label %exit, label %loop

exit:
  ret i32 0
}
""",
    },
]

REPAIR_PROMPT_TEMPLATE = """\
The following LLVM IR failed verification with llvm-as. Fix it and return ONLY \
the corrected IR. Do not explain the changes.

ORIGINAL IR:
```
{original_ir}
```

ERROR FROM llvm-as:
```
{error_message}
```

Remember: use opaque pointers (ptr), count string bytes correctly (including \\00), \
and ensure every basic block has a terminator. Return only the fixed IR.
"""


def build_generation_messages(intent: str, *, include_examples: bool = True) -> list[dict]:
    """Build the message list for an IR generation request."""
    messages = []

    if include_examples:
        for ex in FEW_SHOT_EXAMPLES:
            messages.append({"role": "user", "content": ex["intent"]})
            messages.append({"role": "assistant", "content": ex["ir"]})

    messages.append({"role": "user", "content": intent})
    return messages


def build_repair_messages(original_ir: str, error_message: str) -> list[dict]:
    """Build the message list for a repair request."""
    content = REPAIR_PROMPT_TEMPLATE.format(
        original_ir=original_ir,
        error_message=error_message,
    )
    return [{"role": "user", "content": content}]
