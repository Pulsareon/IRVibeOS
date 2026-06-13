# Tier 1 — Connected Device Seed (ESP32, WiFi MCU)

Status: **planned, not yet implemented.**

## Concept

The tier1 seed targets devices with networking (WiFi/BLE) but limited compute (no local LLVM toolchain, no local AI). The device connects directly to a cloud AI service.

## Architecture

```
seed.ll (IR, ~500 lines):
  - Boot + WiFi connect (calls platform externals)
  - TCP/TLS socket to AI endpoint
  - Vibe loop: send intent, receive IR, load + execute

Platform externals (provided by IDF/SDK, linked as .a):
  - wifi_connect(ssid, pass) -> status
  - tcp_connect(host, port) -> socket
  - tls_handshake(socket, hostname) -> status
  - tcp_send / tcp_recv / tcp_close
```

WiFi/TCP/TLS is **platform infrastructure** (like UART for tier0), not something the seed implements in IR.

## Compilation Problem

ESP32 cannot run `clang`/`llc` locally (520KB SRAM). Options:
1. Cloud compilation: device sends IR text → cloud returns native binary
2. Pre-compiled modules: AI generates IR, build server compiles, OTA push

## Blockers

- Need to decide target: ESP32-C3 (RISC-V) or ESP32-S3 (Xtensa)
- Need ESP-IDF build integration for linking platform libs with IR seed
- TLS requires mbedTLS linked from IDF
