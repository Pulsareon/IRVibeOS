**Language / 语言**: [English](README.md) | [中文](README.zh-CN.md)

# IRVibeOS

IRVibeOS is an LLVM IR-native VibeOS/runtime prototype. The 1.0 hosted release focuses on one useful loop:

```text
intent -> LLVM IR -> verify -> save as module -> run
```

The long-term goal is an operating system surface where software is created from intent and stored as verifiable LLVM IR. The bigger north star is a complete bare-metal OS with a coding-agent interface comparable in workflow quality to Claude Code or Codex. The current usable target is hosted mode on an existing OS.

## Current Status

**Usable in 1.0 hosted mode**

- Verify all LLVM IR files with `tools/verify.ps1`.
- Build all tracked `.ll` files with `tools/build.ps1`.
- Run hosted modules from `modules/<name>/main.ll`.
- Generate a module from an intent with `host/hosted_vibe.py`.
- Run the hosted shell with `lli src_ir\irvibeos.ll`.

**Experimental / roadmap**

- Bare-metal EXEC payload loading.
- Tier1 ESP32 seed.
- Tier2 UEFI seed.
- On-device `vibe_engine.ll` API calls and response parsing.
- Dependency solving beyond the simple `deps.txt` module convention.

## Quick Start

Requirements:

- LLVM tools in PATH: `llvm-as`, `llc`, `lli`.
- Python 3 for host tooling.
- Optional: `requests` for AI providers.

Verify and build:

```powershell
.\tools\verify.ps1
.\tools\build.ps1 -Clean
```

Run the hosted shell:

```powershell
lli src_ir\irvibeos.ll apps
"hello" | lli src_ir\irvibeos.ll run
lli src_ir\irvibeos.ll verify
```

Create a module without network access:

```powershell
python host\hosted_vibe.py --name demo --intent "print a hello message" --provider template --run
```

Create a module with an OpenAI-compatible API:

```powershell
python host\hosted_vibe.py `
  --name ai_demo `
  --intent "print three short lines about LLVM IR" `
  --provider openai-compatible `
  --api-base http://localhost:11434/v1 `
  --api-key dummy `
  --model llama3 `
  --run
```

For OpenAI or Claude, pass `--provider openai` or `--provider claude` with `--api-key` and `--model`, or set `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` plus `IRVIBEOS_MODEL`.

## Architecture

```text
IRVibeOS/
  src_ir/
    irvibeos.ll          hosted IR shell: apps/run/deps/vibe/verify
    vibe_engine.ll       experimental on-device vibe loop

  host/
    hosted_vibe.py       hosted 1.0 intent -> IR -> module tool
    ai_host.py           experimental TALK host for seeds

  modules/
    <name>/main.ll       runnable hosted module
    <name>/deps.txt      simple dependency metadata

  seed/
    tier0_mcu/seed.ll    TALK seed core
    tier3_hosted/seed.ll hosted byte I/O adapter
    tier1_connected/     planned ESP32 seed
    tier2_pc/            planned UEFI seed

  knowledge/             AI reference material, not runtime source
  tools/                 verification and build scripts
```

## Module Contract

A hosted module is a directory under `modules/`:

```text
modules/example/
  main.ll
  deps.txt
```

`main.ll` must define:

```llvm
define i32 @main()
```

`tools/verify.ps1` checks all `.ll` files with `llvm-as` and verifies that every module directory has `main.ll` and `deps.txt`.

## Source Rule

System/device source is LLVM IR (`.ll` or `.bc`). Other languages are allowed only for:

- `host/`: development tools that run on the PC.
- `tools/`: repository verification/build tools.
- `docs/` and `knowledge/`: documentation and AI reference material.

## Roadmap

1. Hosted 1.0: intent-to-module workflow, verification, build, module shell.
2. Hosted 1.x: safer module names, richer metadata, dependency checks, more examples.
3. Seed runtime: define an executable payload format for TALK EXEC.
4. Device-driven vibe: implement `vibe_engine.ll` JSON/API parsing and platform externals.
5. Hardware tiers: implement ESP32 and UEFI seeds.
6. Bare-metal agent OS: QEMU boot, kernel, storage, network, IR runtime, agent tool API, permissions, and rollback.

See `docs/BAREMETAL_AGENT_OS.md` for the full target.

## References

- LLVM Language Reference: https://llvm.org/docs/LangRef.html
- Repository: https://github.com/Pulsareon/IRVibeOS.git
