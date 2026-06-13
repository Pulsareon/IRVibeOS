# Foreign Source Notes

This directory may contain source snippets in C, Rust, Zig, JavaScript, Python, or any other language, but only as documentation.

Rules:

- Files here are not system source.
- Files here are not linked, interpreted, or executed by IRVibeOS.
- AI may use them as explanation or a translation hint.
- To enter the system, the idea must be converted into LLVM IR and reviewed as `.ll` or `.bc`.
- The imported artifact belongs in `src_ir/`, not here.

Recommended naming:

```text
docs/foreign_sources/<idea>.c.md
docs/foreign_sources/<idea>.rs.md
docs/foreign_sources/<idea>.py.md
```

The `.md` suffix is intentional: these are documents, not implementation files.
