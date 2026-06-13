# Tier 2 — PC / VM Seed (UEFI Application)
# 第二级 — PC / 虚拟机种子（UEFI 应用）

Status / 状态: **planned, not yet implemented / 已规划，尚未实现**

## Concept / 概念

The tier2 seed is a UEFI application. UEFI Boot Services already provide display (GOP), keyboard (SimpleTextInput), network (TCP4), memory map, and filesystem access. The seed uses these to connect to AI and enter the vibe loop immediately.

Tier2 种子是一个 UEFI 应用。UEFI Boot Services 已经提供了显示（GOP）、键盘（SimpleTextInput）、网络（TCP4）、内存映射和文件系统访问。种子利用这些直接连接 AI 并进入 vibe 循环。

## Architecture / 架构

```
seed.ll (IR, ~300-400 lines / 约 300-400 行):
  - efi_main(ImageHandle, SystemTable) entry point
    efi_main 入口
  - LocateProtocol calls for GOP, keyboard, TCP4
    LocateProtocol 获取 GOP、键盘、TCP4
  - Basic text output to framebuffer (built-in bitmap font)
    帧缓冲基本文本输出（内置位图字体）
  - TCP connection to AI endpoint (or local LLM socket)
    TCP 连接到 AI 端点（或本地 LLM socket）
  - Vibe loop: display prompt, read intent, send to AI, receive IR, compile, load
    Vibe 循环：显示提示符、读取意图、发送给 AI、接收 IR、编译、加载

Platform externals (UEFI protocols, resolved at link time):
平台外部函数（UEFI 协议，链接时解析）:
  - GOP: framebuffer Blt for text rendering / 帧缓冲文本渲染
  - SimpleTextInput: ReadKeyStroke for keyboard / 键盘读取
  - TCP4: connect, send, receive for AI communication / AI 通信
  - AllocatePages: executable memory for loaded modules / 可执行内存分配
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

## Compilation on Device / 设备端编译

PC has enough resources to run LLVM tools locally:

PC 有足够资源在本地运行 LLVM 工具：

- The AI generates `.ll` text / AI 生成 `.ll` 文本
- The seed calls `llc` + `lld` (or uses ORC JIT via libLLVM) / 调用 llc + lld（或通过 libLLVM 使用 ORC JIT）
- Resulting native code is loaded into allocated executable pages / 编译结果加载到可执行内存页

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
