# Contributing

Thanks for helping IRVibeOS grow.

## Ground Rules

- Keep system/device source in LLVM IR (`.ll` or `.bc`).
- Host tooling may use Python or PowerShell.
- Do not add generated build artifacts to Git.
- Every module under `modules/` must have `main.ll` and `deps.txt`.
- Run verification before opening a PR:

```powershell
.\tools\verify.ps1
.\tools\build.ps1 -Clean
```

## Good First Issues

- Add small hosted modules under `modules/`.
- Improve docs or examples.
- Add tests around `host/hosted_vibe.py`.
- Improve error messages in `tools/verify.ps1`.

## Bigger Areas

- Module manifest design.
- Generated IR repair flow.
- TALK EXEC payload format.
- `src_ir/vibe_engine.ll` API and JSON implementation.
- Tier1/Tier2 seed implementation.
