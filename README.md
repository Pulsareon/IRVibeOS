**Language / 语言**: [English](README.md) | [中文](README.zh-CN.md)

# IRVibeOS

IRVibeOS is an operating system whose entire system source is LLVM IR. It boots from a minimal seed and grows into a full OS where the primary way to create software is **vibe** — describe your intent, get working programs.

## Core Idea

The system starts as a seed and evolves into a complete operating system. Once grown, it works like any OS — running apps, managing resources, providing UI — but with one fundamental difference: **software is created by intent, not by manual coding.**

Users vibe:
- **Programs** — "I need a text editor" → the system generates one
- **Libraries** — "I need an HTTP client" → available as a dependency
- **Services** — "Run a web server on port 8080" → running
- **UI** — complexity scales with hardware (serial text → framebuffer → GPU-accelerated)

Everything produced is LLVM IR. Everything runs natively.

## How It Works

```
┌─────────────────────────────────────────────────────┐
│                  Grown IRVibeOS                       │
│                                                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐             │
│  │  App A  │  │  App B  │  │  App C  │  ← vibed   │
│  └────┬────┘  └────┬────┘  └────┬────┘             │
│       │            │            │                    │
│  ┌────┴────────────┴────────────┴────┐              │
│  │        Libraries / Deps           │  ← vibed    │
│  └────────────────┬──────────────────┘              │
│                   │                                  │
│  ┌────────────────┴──────────────────┐              │
│  │     OS Services (sched, fs, net)  │  ← grown    │
│  └────────────────┬──────────────────┘              │
│                   │                                  │
│  ┌────────────────┴──────────────────┐              │
│  │     Vibe Engine (the core loop)   │  ← seed     │
│  │     intent → IR → verify → load   │              │
│  └───────────────────────────────────┘              │
└─────────────────────────────────────────────────────┘
```

The vibe engine is the one capability that must exist from seed stage onward. It is both the bootstrap mechanism (growing the OS) and the permanent user interface (creating software after the OS is grown).

## The Seed

The seed = the minimum code needed to start the vibe loop on a given hardware class.

What "minimum" means varies by hardware:

| Hardware | Seed provides | Vibe loop powered by |
|----------|--------------|---------------------|
| Weak MCU (8KB RAM) | Boot + UART I/O + execute slot | Host PC with AI pushes code over serial |
| Connected device (ESP32) | Boot + WiFi + execute | Cloud AI, device talks directly |
| PC / VM | UEFI app: display, keyboard, network, memory map | Local LLM or cloud AI, user interacts via keyboard/screen |
| On existing OS | A process | Calls AI API directly, simplest case |

The invariant: once the vibe loop is running, growth begins.

### MCU Seed

Two functions to implement: `seed_recv_byte`, `seed_send_byte`. ~256 bytes compiled.

### PC Seed

A UEFI application. UEFI already provides display, keyboard, memory map, network, filesystem. The seed uses these to connect to AI and enter the vibe loop immediately — no blind probing needed.

### Hosted Seed

A normal process using stdin/stdout. For development and testing.

## TALK Protocol (MCU mode)

For constrained devices communicating with a host:

```
HOST → DEVICE:
  [1B opcode][4B length][payload]
  opcodes: 0x01=EXEC  0x02=PEEK  0x03=POKE

DEVICE → HOST:
  [1B status][4B length][data]
```

Capable devices (PC, ESP32) don't need this protocol — they speak HTTP/API to AI directly.

## Vibe as OS Primitive

Once the system has grown enough, vibe becomes the standard way to get software:

```
user: "I need a file manager"
  → AI generates IR for a file manager
  → system verifies the IR
  → system resolves/vibes any missing dependencies
  → app is loaded and running

user: "add copy/paste support to the editor"
  → AI reads existing editor module
  → generates updated IR
  → hot-reloads the module
```

Vibe can produce:
- Standalone programs (apps)
- Shared libraries (other modules can depend on)
- System services (daemons, drivers)
- UI components (if display hardware exists)

Dependencies are tracked. If app A needs lib X and lib X doesn't exist yet, the system vibes lib X first.

## UI Scaling

The system adapts its interface to available hardware:

| Hardware | UI |
|----------|-----|
| UART only | text commands over serial |
| Character LCD | minimal status display |
| Framebuffer | terminal UI, simple graphics |
| GPU | window manager, compositing, rich apps |

UI is not pre-built — it's vibed to match what the hardware can do.

## Repository as Knowledge

The GitHub repository (https://github.com/Pulsareon/IRVibeOS.git) serves as AI's reference knowledge — not a package registry.

- In constrained mode: the host AI reads the repo for patterns and platform notes
- In full mode: once the device has network, its AI can fetch references from the repo
- The AI adapts what it reads to the current device — never blindly copies

## Repository Structure

```
IRVibeOS/
  seed/                   seeds for each hardware tier
    tier0_mcu/            weak MCU: UART byte-level seed
    tier1_connected/      networked device: WiFi/BLE seed
    tier2_pc/             PC/VM: UEFI application seed
    tier3_hosted/         on existing OS: process-level seed

  knowledge/              AI reference (not executed by device)
    patterns/             general IR patterns
    platforms/            platform notes and memory maps
    examples/             previously grown modules

  host/                   host-side tools
    ai_host.py            communicates with seed over serial

  src_ir/                 legacy hosted shell (development aid)
    irvibeos.ll

  modules/                hosted-mode IR apps
```

## Hard Source Rule

All system source is LLVM IR (`.ll` or `.bc`). Other languages appear only in:

- `knowledge/` as reference for AI
- `host/` as tooling (runs on PC, not on device)
- `docs/` as documentation

The device never executes anything that wasn't generated as LLVM IR.

## Quick Start (Hosted Mode)

The legacy shell still works for development:

```powershell
lli src_ir\irvibeos.ll
```

## References

- LLVM Language Reference: https://llvm.org/docs/LangRef.html
- Repository: https://github.com/Pulsareon/IRVibeOS.git
