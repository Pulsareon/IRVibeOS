# Host Tools / 上位机工具

This directory contains tools that run on the host PC to communicate with IRVibeOS seeds and provide AI-powered code generation.

本目录包含运行在上位机 PC 上的工具，用于与 IRVibeOS 种子通信并提供 AI 驱动的代码生成。

These are **not** part of the OS — they run on the development machine.

这些**不是** OS 的一部分——它们运行在开发机器上。

## ai_host.py

Full-featured host implementation combining:
- TALK protocol client (communicates with seed)
- AI integration (OpenAI-compatible or Claude)
- LLVM IR compilation (via `llc`)

功能完整的宿主端实现，结合了：
- TALK 协议客户端（与种子通信）
- AI 集成（OpenAI 兼容或 Claude）
- LLVM IR 编译（通过 `llc`）

### Installation / 安装

```bash
pip install requests pyserial
```

LLVM toolchain (`llc`) must be in PATH.
LLVM 工具链（`llc`）必须在 PATH 中。

### Usage Examples / 使用示例

#### Serial mode with OpenAI / 串口模式 + OpenAI

```bash
python ai_host.py --port COM3 --baud 115200 \
  --ai openai --api-key sk-... --model gpt-4
```

#### Serial mode with Claude / 串口模式 + Claude

```bash
python ai_host.py --port COM3 \
  --ai claude --api-key sk-ant-...
```

#### OpenAI-compatible (e.g., Ollama local) / OpenAI 兼容（如本地 Ollama）

```bash
python ai_host.py --port COM3 \
  --ai openai-compatible \
  --api-base http://localhost:11434/v1 \
  --api-key dummy \
  --model llama3
```

#### Hosted seed testing / 宿主种子测试

```powershell
# Build the hosted seed / 构建宿主种子
llvm-link seed\tier0_mcu\seed.ll seed\tier3_hosted\seed.ll -o build\seed.bc

# Run in one terminal / 一个终端运行
lli build\seed.bc

# Connect from another (requires bidirectional pipe setup)
# 从另一个终端连接（需要双向管道配置）
```

### Commands / 命令

| Command / 命令 | Description / 说明 |
|----------------|-------------------|
| `info` | Query device identity and code slot size<br>查询设备身份和代码槽大小 |
| `peek <hex_addr> <len>` | Read device memory<br>读设备内存 |
| `poke <hex_addr> <hex>` | Write bytes to device memory<br>写字节到设备内存 |
| `exec <file>` | Send binary file and execute<br>发送并执行二进制文件 |
| `compile <ll_file>` | Compile .ll to native and execute<br>编译 .ll 为原生代码并执行 |
| `vibe <intent>` | **AI generates IR for intent, compiles, executes**<br>**AI 为意图生成 IR、编译、执行** |
| `quit` | Exit<br>退出 |

### Vibe Workflow / Vibe 工作流

```
user> vibe print hello world

  1. Host sends intent to AI API / 上位机发送意图到 AI API
  2. AI returns LLVM IR implementing it / AI 返回实现该意图的 LLVM IR
  3. Host compiles IR to native code via llc / 上位机通过 llc 编译 IR 为原生代码
  4. Host sends native code to device via EXEC / 上位机通过 EXEC 发送原生代码到设备
  5. Device executes and returns result / 设备执行并返回结果
```

## Protocol Reference / 协议参考

```
Sync word / 同步字: 0xAA 0x55 (precedes every message / 每条消息前都有)

HOST → DEVICE / 上位机 → 设备:
  [0xAA 0x55][1B opcode][4B length][payload]
  opcodes / 操作码:
    0x01 = EXEC  [4B len][code]     execute and return i32 / 执行并返回 i32
    0x02 = PEEK  [8B addr][4B len]  read memory / 读内存
    0x03 = POKE  [8B addr][4B len][data]  write memory / 写内存
    0x04 = INFO  []                 get device info / 获取设备信息

DEVICE → HOST / 设备 → 上位机:
  [0xAA 0x55][1B status][4B length][data]
  status / 状态:
    0x00 = OK / 成功
    0xFE = unknown opcode / 未知操作码
```

## Supported AI Providers / 支持的 AI 提供商

### OpenAI

```bash
--ai openai --api-key sk-... --model gpt-4
```

API base: `https://api.openai.com/v1`

### Claude (Anthropic)

```bash
--ai claude --api-key sk-ant-... --model claude-opus-4-20250514
```

API endpoint: `https://api.anthropic.com/v1/messages`

### OpenAI-compatible APIs / OpenAI 兼容 API

Any service implementing OpenAI's chat completion format:
任何实现 OpenAI chat completion 格式的服务：

- **Ollama** (local): `http://localhost:11434/v1`
- **LM Studio**: `http://localhost:1234/v1`
- **vLLM**: custom endpoint / 自定义端点
- **OpenRouter**: `https://openrouter.ai/api/v1`

```bash
--ai openai-compatible --api-base <url> --api-key <key> --model <model>
```

## Future: On-Device AI / 未来：设备端 AI

Currently, AI runs on the host PC. Once a capable device (tier2 PC/VM) has network:

当前 AI 运行在上位机 PC 上。一旦有能力的设备（tier2 PC/VM）有网络后：

1. Device calls AI API directly / 设备直接调用 AI API
2. Device compiles IR locally (via `llc` on device) / 设备本地编译 IR（通过设备上的 `llc`）
3. Device loads and runs without host / 设备无需上位机即可加载运行
4. Host becomes optional / 上位机变为可选

This transition is seamless — same protocol, different topology.

此转换无缝——相同协议，不同拓扑。
