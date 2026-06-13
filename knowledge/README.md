# Knowledge Base / 知识库

This directory contains reference material for AI — patterns, platform notes, and examples of previously grown modules.

本目录包含 AI 参考资料——模式、平台笔记和以往生长成果的示例。

**These files are NOT executed on devices.** They exist so that AI (whether running on a host PC or accessed via network) can consult prior experience when generating new code for a specific target.

**这些文件不在设备上执行。** 它们的存在是为了让 AI（无论运行在上位机还是通过网络访问）在为特定目标生成代码时可以参考已有经验。

## Structure / 结构

```
knowledge/
  patterns/       general LLVM IR patterns (UART I/O, interrupt vectors, allocators, etc.)
                  通用 LLVM IR 模式（UART I/O、中断向量、分配器等）
  platforms/      platform-specific notes (memory maps, register addresses, boot sequences)
                  平台特定笔记（内存映射、寄存器地址、启动流程）
  examples/       previously grown modules that worked on real hardware
                  以往在真实硬件上跑通的生长成果
```

## Usage / 使用方式

- In **constrained mode**: the host AI reads these files to inform code generation for the target MCU.
  **受限模式**下：上位机 AI 读取这些文件来指导为目标 MCU 生成代码。
- In **full mode**: once a device has network, its AI can fetch these files from GitHub as reference.
  **全能模式**下：设备有网络后，AI 可以从 GitHub 拉取这些文件作参考。

The content here is "experience" — not packages to install, but knowledge to adapt.

这里的内容是"经验"——不是要安装的包，而是可供借鉴的知识。
