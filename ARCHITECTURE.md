# IRVibeOS Architecture

## 1.0 Scope

IRVibeOS 1.0 is a hosted LLVM IR runtime prototype. Its reliable workflow is:

```text
intent -> LLVM IR -> verify -> module registry -> run
```

The project deliberately separates current hosted capability from future device-driven OS capability.

## Layers

### Hosted Runtime Surface

File: `src_ir/irvibeos.ll`

Responsibilities:

- List modules.
- Run `modules/<name>/main.ll` with `lli`.
- Show dependencies from `deps.txt`.
- Trigger repository verification.
- Generate simple IR modules through the legacy `vibe` command.

### Hosted Vibe Tool

File: `host/hosted_vibe.py`

Responsibilities:

- Accept an intent.
- Generate LLVM IR through either an offline template or an AI provider.
- Verify the generated IR with `llvm-as`.
- Save the module to `modules/<name>/main.ll`.
- Optionally run it with `lli`.

### Module Registry

Directory: `modules/`

Contract:

```text
modules/<name>/main.ll
modules/<name>/deps.txt
```

`tools/verify.ps1` enforces this basic contract.

### Seeds

Directory: `seed/`

Current:

- `tier0_mcu/seed.ll`: TALK protocol core.
- `tier3_hosted/seed.ll`: hosted byte I/O adapter.

Planned:

- `tier1_connected/`: ESP32/networked device seed.
- `tier2_pc/`: UEFI seed.

### Device Vibe Engine

File: `src_ir/vibe_engine.ll`

Status: experimental. It documents the intended on-device AI loop but still needs API request construction, JSON parsing, and platform externals.

## Design Rules

- System/device source is LLVM IR.
- Host and repository tooling may use Python or PowerShell.
- AI-generated software should be saved as LLVM IR before it becomes a module.
- Generated IR must pass `llvm-as` before being registered.
- Hardware-specific execution must not assume object files are directly callable payloads.
