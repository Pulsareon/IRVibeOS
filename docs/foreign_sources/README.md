# Foreign Source Notes / 外部语言备注

This directory may contain source snippets in C, Rust, Zig, JavaScript, Python, or any other language, but only as documentation.

本目录可包含 C、Rust、Zig、JavaScript、Python 或其他语言的代码片段，但仅作为文档。

## Rules / 规则

- Files here are not system source. / 此处文件不是系统源码。
- Files here are not linked, interpreted, or executed by IRVibeOS. / 不会被 IRVibeOS 链接、解释或执行。
- AI may use them as explanation or a translation hint. / AI 可将其用作解释或翻译提示。
- To enter the system, the idea must be converted into LLVM IR and reviewed as `.ll` or `.bc`. / 要进入系统，必须转换为 LLVM IR 并以 `.ll` 或 `.bc` 形式审查。
- The imported artifact belongs in `src_ir/`, not here. / 导入的产物属于 `src_ir/`，不属于此处。

## Recommended naming / 推荐命名

```text
docs/foreign_sources/<idea>.c.md
docs/foreign_sources/<idea>.rs.md
docs/foreign_sources/<idea>.py.md
```

The `.md` suffix is intentional: these are documents, not implementation files.

`.md` 后缀是故意的：这些是文档，不是实现文件。
