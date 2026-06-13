# Tier 2 — PC / VM Seed (UEFI Application)
# 第二级 — PC / 虚拟机种子（UEFI 应用）

Status / 状态: **planned, not yet implemented / 已规划，尚未实现**

## Concept / 概念

The tier2 seed is a UEFI application. UEFI Boot Services already provide display (GOP), keyboard (SimpleTextInput), network (TCP4), memory map, and filesystem access. The seed uses these to connect to AI and enter the vibe loop immediately.

Tier2 种子是一个 UEFI 应用。UEFI Boot Services 已经提供了显示（GOP）、键盘（SimpleTextInput）、网络（TCP4）、内存映射和文件系统访问。种子利用这些直接连接 AI 并进入 vibe 循环。

## Architecture / 架构

### Two Operating Modes / 两种操作模式

**Mode A: Host-driven vibe (development) / 上位机驱动的 vibe（开发）**
- Another PC runs `ai_host.py vibe <intent>`
- AI generates IR, compiles to x86-64/ARM64
- Host sends native code via network or serial TALK protocol
- Device executes received code
- **Used for**: initial bootstrap, cross-platform development
- **用于**：初始引导、跨平台开发

**Mode B: Device-driven vibe (autonomous) / 设备驱动的 vibe（自主）**
- Device loads `vibe_engine.ll` + LLVM toolchain (once, via Mode A or EFI partition)
- Device accepts user intent via GOP display + keyboard
- Device calls AI API over TCP/TLS (UEFI protocols)
- **AI generates LLVM IR** (`.ll` format)
- Device compiles IR locally using `llc` or ORC JIT
- Device loads and executes compiled code
- **Used for**: standalone operation, no external dependencies
- **用于**：独立运行，无外部依赖

**IR-first architecture**: Tier2 preserves the LLVM IR source model. All generated code is IR that gets compiled locally, maintaining the system's IR-as-source philosophy.

**IR 优先架构**：Tier2 保留 LLVM IR 源码模型。所有生成的代码都是 IR，在本地编译，维持系统 IR 即源码的理念。

```
seed.ll (IR, ~300-400 lines / 约 300-400 行):
  - efi_main(ImageHandle, SystemTable) entry point
    efi_main 入口
  - LocateProtocol calls for GOP, keyboard, TCP4
    LocateProtocol 获取 GOP、键盘、TCP4
  - Basic text output to framebuffer (built-in bitmap font)
    帧缓冲基本文本输出（内置位图字体）
  - Load vibe_engine.ll from EFI partition or receive via network
    从 EFI 分区加载 vibe_engine.ll 或通过网络接收
  - Jump to vibe_loop() → device becomes autonomous
    跳转到 vibe_loop() → 设备变为自主模式

vibe_engine.ll (from src_ir/, ~400 lines / 来自 src_ir/，约 400 行):
  - Vibe loop: display prompt, read intent, call AI API
    Vibe 循环：显示提示符、读取意图、调用 AI API
  - AI generates LLVM IR
    AI 生成 LLVM IR
  - Compile IR locally using llc or ORC JIT
    使用 llc 或 ORC JIT 本地编译 IR
  - Load and execute compiled code
    加载并执行编译后的代码

Platform externals (UEFI protocols, resolved at link time):
平台外部函数（UEFI 协议，链接时解析）:
  - GOP: framebuffer Blt for text rendering / 帧缓冲文本渲染
  - SimpleTextInput: ReadKeyStroke for keyboard / 键盘读取
  - TCP4: connect, send, receive for AI communication / AI 通信
  - AllocatePages: executable memory for loaded modules / 可执行内存分配
  - SimpleFileSystem: read LLVM tools from EFI partition / 从 EFI 分区读取 LLVM 工具
```

## TLS Strategy / TLS 策略

Do not write TLS in IR from scratch. Options:

不要用 IR 从零写 TLS。方案：

1. Link against EDK2's pre-built TlsLib (mbedTLS compiled for UEFI)
   链接 EDK2 预编译的 TlsLib（为 UEFI 编译的 mbedTLS）
2. Use plain HTTP to a local AI proxy (simplest for development)
   用明文 HTTP 连本地 AI 代理（最简单的开发方案）
3. Vibe the TLS module once the system is running
   系统跑起来后再 vibe 出 TLS 模块

## Code Generation / 代码生成

PC has enough resources to run LLVM tools locally. Two approaches:

PC 有足够资源在本地运行 LLVM 工具。两种方法：

**Approach 1: AI generates machine code directly** (faster, simpler)
- AI is prompted with target architecture ("x86-64" or "aarch64")
- AI returns base64-encoded executable machine code
- Device decodes and loads into executable pages
- **Best for**: simple utilities, quick prototyping

**方法 1：AI 直接生成机器码**（更快，更简单）
- AI 获得目标架构提示（"x86-64" 或 "aarch64"）
- AI 返回 base64 编码的可执行机器码
- 设备解码并加载到可执行页
- **适用于**：简单工具、快速原型

**Approach 2: AI generates LLVM IR, device compiles locally** (more reliable for complex code)
- AI generates LLVM IR (.ll format)
- Device calls `llc` binary stored on EFI partition, or uses ORC JIT
- Resulting native code is loaded into allocated executable pages
- **Best for**: complex functionality, multi-file modules, debugging

**方法 2：AI 生成 LLVM IR，设备本地编译**（复杂代码更可靠）
- AI 生成 LLVM IR（.ll 格式）
- 设备调用存储在 EFI 分区的 `llc` 二进制，或使用 ORC JIT
- 编译结果加载到分配的可执行页
- **适用于**：复杂功能、多文件模块、调试

The vibe engine can support both approaches and choose based on the task complexity or user preference.

Vibe 引擎可以支持两种方法，并根据任务复杂度或用户偏好选择。

## Build / 构建

```
clang -target x86_64-unknown-windows -ffreestanding -c seed.ll -o seed.o
lld-link /subsystem:efi_application /entry:efi_main seed.o edk2libs.lib -o seed.efi
```

Run in QEMU / 在 QEMU 中运行:
```
qemu-system-x86_64 -bios OVMF.fd -drive format=raw,file=fat:rw:esp/
```
(where `esp/EFI/BOOT/BOOTX64.EFI` is `seed.efi` / 其中 `esp/EFI/BOOT/BOOTX64.EFI` 是 `seed.efi`)

## Blockers / 阻塞项

- Need OVMF + QEMU setup for testing / 需要配置 OVMF + QEMU 测试环境
- Need minimal GOP font renderer (~100 lines IR) / 需要最小 GOP 字体渲染器（约 100 行 IR）
- Decide: link EDK2 TLS vs local HTTP proxy for initial AI access
  需要决定：链接 EDK2 TLS 还是用本地 HTTP 代理做初始 AI 接入
