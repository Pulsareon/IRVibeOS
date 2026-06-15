**语言 / Language**: [English](README.md) | [中文](README.zh-CN.md)

# IRVibeOS

IRVibeOS 是一个以 LLVM IR 为核心源格式的 VibeOS/runtime 原型。当前 1.0 hosted 版本先聚焦一条真正可用的闭环：

```text
意图 -> LLVM IR -> 验证 -> 保存为模块 -> 运行
```

长期目标是一个通过意图创建软件、并把软件保存为可验证 LLVM IR 的操作系统表面。更远的北极星是完整裸机 OS，加上接近 Claude Code / Codex 工作流质量的编码智能体界面。当前可用目标是运行在已有操作系统上的 hosted 模式。

## 当前状态

**1.0 hosted 模式已经可用**

- 用 `tools/verify.ps1` 验证全部 LLVM IR。
- 用 `tools/build.ps1` 构建全部 `.ll` 文件。
- 运行 `modules/<name>/main.ll` 形式的 hosted 模块。
- 用 `host/hosted_vibe.py` 从意图生成模块。
- 用 `lli src_ir\irvibeos.ll` 运行 hosted IR shell。

**实验中 / 路线图**

- 裸机 EXEC payload 装载。
- Tier1 ESP32 seed。
- Tier2 UEFI seed。
- 设备端 `vibe_engine.ll` 的 API 请求和响应解析。
- 超出 `deps.txt` 简单约定的依赖求解。

## 快速开始

需要：

- LLVM 工具在 PATH 中：`llvm-as`、`llc`、`lli`。
- Python 3。
- 可选：使用 AI provider 时安装 `requests`。

验证和构建：

```powershell
.\tools\verify.ps1
.\tools\build.ps1 -Clean
```

运行 hosted shell：

```powershell
lli src_ir\irvibeos.ll apps
"hello" | lli src_ir\irvibeos.ll run
lli src_ir\irvibeos.ll verify
```

无网络生成一个模块：

```powershell
python host\hosted_vibe.py --name demo --intent "print a hello message" --provider template --run
```

使用 OpenAI 兼容 API 生成模块：

```powershell
python host\hosted_vibe.py `
  --name ai_demo `
  --intent "print three short lines about LLVM IR" `
  --provider openai-compatible `
  --api-base http://localhost:11434/v1 `
  --api-key dummy `
  --model llama3 `
  --run
```

使用 OpenAI 或 Claude 时，传入 `--provider openai` 或 `--provider claude`，并提供 `--api-key` 和 `--model`；也可以设置 `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` 与 `IRVIBEOS_MODEL`。

## 架构

```text
IRVibeOS/
  src_ir/
    irvibeos.ll          hosted IR shell：apps/run/deps/vibe/verify
    vibe_engine.ll       实验性的设备端 vibe loop

  host/
    hosted_vibe.py       1.0 hosted 意图 -> IR -> 模块工具
    ai_host.py           实验性的 TALK seed 上位机

  modules/
    <name>/main.ll       可运行 hosted 模块
    <name>/deps.txt      简单依赖元数据

  seed/
    tier0_mcu/seed.ll    TALK seed 核心
    tier3_hosted/seed.ll hosted 字节 I/O 适配
    tier1_connected/     规划中的 ESP32 seed
    tier2_pc/            规划中的 UEFI seed

  knowledge/             AI 参考资料，不是运行时源码
  tools/                 验证和构建脚本
```

## 模块约定

hosted 模块位于 `modules/`：

```text
modules/example/
  main.ll
  deps.txt
```

`main.ll` 必须定义：

```llvm
define i32 @main()
```

`tools/verify.ps1` 会用 `llvm-as` 检查全部 `.ll`，并确认每个模块目录都有 `main.ll` 和 `deps.txt`。

## 源码规则

系统/设备源码是 LLVM IR（`.ll` 或 `.bc`）。其他语言只允许出现在：

- `host/`：运行在 PC 上的开发工具。
- `tools/`：仓库验证和构建工具。
- `docs/` 与 `knowledge/`：文档和 AI 参考资料。

## 路线图

1. Hosted 1.0：意图到模块、验证、构建、模块 shell。
2. Hosted 1.x：更安全的模块名、更丰富的元数据、依赖检查、更多示例。
3. Seed runtime：定义 TALK EXEC 的可执行 payload 格式。
4. 设备端 vibe：实现 `vibe_engine.ll` 的 JSON/API 解析和平台外部函数。
5. 硬件层级：实现 ESP32 与 UEFI seeds。
6. 裸机智能体 OS：QEMU 启动、内核、存储、网络、IR runtime、agent tool API、权限和回滚模型。

完整目标见 `docs/BAREMETAL_AGENT_OS.md`。

## 参考

- LLVM Language Reference: https://llvm.org/docs/LangRef.html
- 仓库地址: https://github.com/Pulsareon/IRVibeOS.git
