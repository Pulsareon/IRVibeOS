# IRVibeOS Roadmap

## North Star

The long-term target is a bare-metal operating system with a coding-agent interface comparable in workflow quality to Claude Code or Codex.

This requires a real OS plus an agent runtime. The OS should provide boot, memory, storage, networking, IR verification/execution, workspace tools, permission boundaries, and a model connector. The model may be remote first and local later.

See `docs/BAREMETAL_AGENT_OS.md`.

## Hosted 1.0

Status: current target.

- [x] Verify all `.ll` files with `llvm-as`.
- [x] Enforce simple module contract.
- [x] Build all discovered `.ll` files.
- [x] Run hosted modules through `lli`.
- [x] Generate hosted modules from intent with `hosted_vibe.py`.
- [ ] Add CI for verify/build/smoke tests.
- [ ] Add more example modules.

## Hosted 1.x

- [ ] Add `module.toml` or an IR-native manifest convention.
- [ ] Add dependency validation beyond plain `deps.txt`.
- [ ] Add generated IR repair loop when `llvm-as` fails.
- [ ] Add provider examples for common local and cloud model servers.
- [ ] Add safer hosted shell command execution.

## Seed Runtime

- [ ] Define the TALK EXEC payload format.
- [ ] Stop sending plain object files as executable payloads.
- [ ] Add a minimal raw-code or image loader path.
- [ ] Add seed integration tests for INFO/EXEC error paths.

## Device-Driven Vibe

- [ ] Implement API request builders in `src_ir/vibe_engine.ll`.
- [ ] Implement JSON response extraction.
- [ ] Implement base64 extraction/decoding for Tier1.
- [ ] Provide platform externals for display/input/network/memory.

## Hardware Tiers

- [ ] Implement Tier1 connected seed.
- [ ] Implement Tier2 UEFI seed.
- [ ] Produce one reproducible hardware demo.

## Bare-Metal Agent OS

- [ ] Boot in QEMU with console output.
- [ ] Add allocator, interrupt setup, and module memory region.
- [ ] Define executable payload format for IR-derived modules.
- [ ] Add persistent workspace storage.
- [ ] Add network/model connector.
- [ ] Add agent tool API: read, write, patch, build, test, verify.
- [ ] Add permission and rollback model.
- [ ] Build a coding-agent UI loop on top of the tool API.
