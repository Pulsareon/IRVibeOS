# IRVibeOS Project Status

Generated: 2026-06-15
Release target: Hosted 1.0

## Health

Project health: **usable hosted prototype**

The repository now has a working hosted loop:

```text
intent -> LLVM IR -> llvm-as verification -> modules/<name>/main.ll -> lli run
```

This is not yet a complete standalone OS. Device-driven vibe and hardware-specific seeds are still roadmap items.

## Verified Locally

- `tools/verify.ps1`: 12/12 IR files valid, 0 project issues.
- `tools/build.ps1 -Clean`: 12/12 object builds succeeded.
- `tools/build.ps1 -Target "thumbv7m-none-eabi" -OutputDir "build_arm" -Clean`: 12/12 object builds succeeded.
- `lli src_ir\irvibeos.ll verify`: works.
- Hosted modules `hello`, `test`, and `testmod`: run through the IR shell.
- `host/hosted_vibe.py --provider template --run`: offline intent-to-module path works.

## What Works

- Hosted IR shell: `apps`, `run`, `deps`, `vibe`, `verify`, `rewrite`, `exec`.
- Hosted module convention: `modules/<name>/main.ll` and `deps.txt`.
- Full-repo IR verification using `llvm-as`.
- Full-repo object generation using `llc`.
- Hosted intent-to-module tool with offline template provider and optional AI providers.

## What Is Experimental

- `host/ai_host.py` TALK integration.
- `seed/tier0_mcu/seed.ll` EXEC runtime beyond INFO/PEEK/POKE basics.
- `src_ir/vibe_engine.ll` on-device AI loop.
- Tier1 connected device seed.
- Tier2 UEFI seed.

## Known Gaps Before Full OS Claims

1. Define a real executable payload format for TALK EXEC.
2. Implement or replace object-file direct execution in `host/ai_host.py`.
3. Implement JSON/API request construction and response parsing in `src_ir/vibe_engine.ll`.
4. Add module metadata richer than `deps.txt`.
5. Add automated CI for LLVM verification and hosted smoke tests.
6. Implement Tier1 and Tier2 seeds.

## Recommended Next Milestones

1. Hosted 1.0 polish: docs, examples, CI, model/provider instructions.
2. Hosted 1.1: module manifest and dependency validation.
3. Seed 0.1: stable TALK EXEC payload format.
4. Device vibe 0.1: implement platform externals and API parsing.
5. Hardware demos: ESP32 and UEFI seed prototypes.
