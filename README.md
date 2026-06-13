# IRVibeOS

IRVibeOS is an experiment for an operating surface whose system source is LLVM IR.

The project keeps only four built-in capabilities:

- `vibe`: accept intent and require AI output to be LLVM IR before import
- `net`: fetch data from the network
- `rewrite`: write or replace LLVM IR modules
- `exec`: execute LLVM IR or binaries produced from LLVM IR

Everything else must be discovered by AI through LLVM IR, bitcode, and generated binaries.

## CLI UI

Run without arguments to enter the DOS/Linux-style shell:

```powershell
lli src_ir\irvibeos.ll
```

Available commands:

```text
help      show shell commands
apps      list dynamic IR modules under modules/
deps      prompt for a module and print modules/<name>/deps.txt
run       prompt for a module and execute modules/<name>/main.ll
load      prompt for a module, show dependencies, then execute module IR
vibe      accept intent; imported code must still be LLVM IR
net       fetch network data into data/net.last
rewrite   write data/generated.ll
exec      execute data/generated.ll through lli
boot      print core status
exit      leave shell
```

The shell itself is implemented in `src_ir/irvibeos.ll`.

## Modular Apps

A module is a directory under `modules/`:

```text
modules/<name>/
  main.ll      executable LLVM IR entry
  deps.txt     dependency metadata
```

`load` is the first dynamic-loading contract. It resolves the module name at runtime, prints dependency metadata, then executes `main.ll` with `lli`.

Current example:

```powershell
lli src_ir\irvibeos.ll
irvibeos> apps
irvibeos> deps
module> hello
irvibeos> load
module> hello
```

## Hard Source Rule

`src_ir/` is the system source tree. It may contain only:

- `.ll` LLVM assembly IR
- `.bc` LLVM bitcode
- plain metadata files that describe IR packages

Other languages are allowed only as documentation or conversion notes under `docs/foreign_sources/`.
They must not be imported into `src_ir/` directly, and they must not be treated as system implementation.

The import path is always:

```text
foreign-language draft or explanation
    -> temporary compiler/frontend output
    -> LLVM IR review
    -> src_ir/*.ll or src_ir/*.bc
```

For C-like input, a temporary conversion can be:

```powershell
clang -S -emit-llvm temp\idea.c -o temp\idea.ll
```

Only `temp\idea.ll` can be considered for import into `src_ir/`.

## Layout

```text
IRVibeOS/
  src_ir/                 system source, LLVM IR only
  modules/                modular IR apps and dependency metadata
  examples/               runnable IR examples
  docs/foreign_sources/   non-IR source kept only as documentation
  data/                   generated modules and network output
```

## Run

```powershell
lli src_ir\irvibeos.ll boot
lli src_ir\irvibeos.ll rewrite
lli src_ir\irvibeos.ll exec
lli src_ir\irvibeos.ll net
lli src_ir\irvibeos.ll vibe
```

Validate IR:

```powershell
opt -S src_ir\irvibeos.ll -o NUL
lli examples\hello.ll
```

## Current Seed

`src_ir/irvibeos.ll` is the minimal seed. It is intentionally tiny: it delegates network and execution to host process calls for now, but the control surface itself is LLVM IR.

Future work should replace those host process calls with IR-defined capability boundaries and AI-generated IR modules.

Reference: LLVM Language Reference Manual: https://llvm.org/docs/LangRef.html
