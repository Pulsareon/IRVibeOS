# Tier 2 — PC / VM Seed (UEFI Application)

Status: **planned, not yet implemented.**

## Concept

The tier2 seed is a UEFI application. UEFI Boot Services already provide display (GOP), keyboard (SimpleTextInput), network (TCP4), memory map, and filesystem access. The seed uses these to connect to AI and enter the vibe loop immediately.

## Architecture

```
seed.ll (IR, ~300-400 lines):
  - efi_main(ImageHandle, SystemTable) entry point
  - LocateProtocol calls for GOP, keyboard, TCP4
  - Basic text output to framebuffer (built-in bitmap font)
  - TCP connection to AI endpoint (or local LLM socket)
  - Vibe loop: display prompt, read intent, send to AI, receive IR, compile, load

Platform externals (UEFI protocols, resolved at link time):
  - GOP: framebuffer Blt for text rendering
  - SimpleTextInput: ReadKeyStroke for keyboard
  - TCP4: connect, send, receive for AI communication
  - AllocatePages: executable memory for loaded modules
```

## TLS Strategy

Do not write TLS in IR from scratch. Options:
1. Link against EDK2's pre-built TlsLib (mbedTLS compiled for UEFI)
2. Use plain HTTP to a local AI proxy (simplest for development)
3. Vibe the TLS module once the system is running

## Compilation on Device

PC has enough resources to run LLVM tools locally:
- The AI generates `.ll` text
- The seed shells out to `llc` + `lld` (or uses ORC JIT via libLLVM)
- Resulting native code is loaded into allocated executable pages

## Build

```
clang -target x86_64-unknown-windows -ffreestanding -c seed.ll -o seed.o
lld-link /subsystem:efi_application /entry:efi_main seed.o edk2libs.lib -o seed.efi
```

Run in QEMU:
```
qemu-system-x86_64 -bios OVMF.fd -drive format=raw,file=fat:rw:esp/
```
(where `esp/EFI/BOOT/BOOTX64.EFI` is `seed.efi`)

## Blockers

- Need OVMF + QEMU setup for testing
- Need minimal GOP font renderer (~100 lines IR)
- Decide: link EDK2 TLS vs local HTTP proxy for initial AI access
