# Bare-Metal Agent OS Target

This document defines the long-term target for IRVibeOS: a bare-metal operating system with a coding-agent interface comparable in workflow quality to tools such as Claude Code or Codex.

## Important Boundary

IRVibeOS cannot become a Claude Code/Codex-level system by OS code alone.

That level requires two parts:

1. A capable model, either remote or local.
2. An agent runtime that gives the model safe, structured tools for reading, editing, verifying, building, running, and reasoning about software.

IRVibeOS should own the second part first. The model can be external in early versions and local only when hardware allows it.

## Target Definition

A complete bare-metal IRVibeOS should eventually provide:

- Bootable kernel on real hardware or VM.
- Memory management.
- Scheduler.
- Interrupt handling.
- Device drivers.
- Storage and file system.
- Network stack.
- Terminal or graphical UI.
- LLVM IR module registry.
- IR verification and compilation/JIT path.
- Safe module loading and execution.
- Agent tool API.
- Persistent project/workspace state.
- Permission and sandbox model.
- Model connector for remote or local AI.

## Agent-Level Requirements

To approach Claude Code/Codex-like usefulness, the OS needs an agent runtime with these capabilities:

- Workspace indexing and search.
- File read/write tools.
- Patch application.
- Build and test execution.
- Diagnostics parsing.
- Incremental planning.
- Context summarization.
- Project memory.
- Tool permission boundaries.
- Rollback or snapshot support.
- Multi-step task execution.
- Verification-before-completion policy.

The agent should not merely generate code. It should operate a loop:

```text
goal -> inspect -> plan -> edit -> verify -> repair -> report
```

## Architecture Direction

```text
Hardware / VM
  -> boot seed
  -> kernel
  -> driver layer
  -> storage + network
  -> IR runtime
  -> module registry
  -> agent tool API
  -> model connector
  -> coding-agent UI
```

## Milestones

### M0: Hosted Agent Runtime

Current direction.

- Use existing OS process.
- Generate LLVM IR modules from intent.
- Verify with `llvm-as`.
- Run with `lli`.
- Save modules under `modules/`.

### M1: Bootable Kernel

- Boot in QEMU first.
- Minimal console output.
- Memory map discovery.
- Interrupt setup.
- Basic allocator.

### M2: Bare-Metal IR Runtime

- Load IR-derived modules as a controlled executable format.
- Define executable payload format.
- Add module metadata.
- Add crash isolation where possible.

### M3: Storage and Project Workspace

- Persistent module store.
- Workspace tree.
- File read/write APIs.
- Snapshot/rollback.

### M4: Networked Agent

- TCP/IP or host bridge.
- Remote model connector.
- JSON request/response support.
- Tool-call protocol.

### M5: Coding-Agent OS

- Repo indexing.
- Patch tools.
- Build/test tools.
- Planner loop.
- Verification loop.
- User approval and permission model.

### M6: Local Model Option

- Only for capable hardware.
- Local inference service or accelerator integration.
- Same agent tool API as remote model mode.

## Non-Goals For Early Versions

- Training a frontier AI model inside the OS.
- Matching cloud coding agents without a capable model.
- Supporting every hardware platform at once.
- Replacing mature OSes before the hosted and VM paths are reliable.

## Practical Strategy

The fastest credible path is:

1. Make hosted mode excellent.
2. Add a VM-first kernel.
3. Move the hosted agent runtime concepts into the VM.
4. Use remote models at first.
5. Add local model support only after the OS has storage, networking, and process isolation.

