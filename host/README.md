# Host Tools / 上位机工具

This directory contains tools that run on the host PC to communicate with IRVibeOS seeds over serial or stdin/stdout pipe.

本目录包含运行在上位机 PC 上的工具，用于通过串口或标准输入/输出管道与 IRVibeOS 种子通信。

These are **not** part of the OS — they run on the development machine and speak the TALK protocol to the seed.

这些**不是** OS 的一部分——它们运行在开发机器上，通过 TALK 协议与种子对话。

## ai_host.py

Reference implementation of the host-side TALK protocol. / TALK 协议宿主端的参考实现。

Commands / 命令:

- `info` — query device identity and code slot size / 查询设备身份和代码槽大小
- `peek <addr> <len>` — read device memory / 读设备内存
- `poke <addr> <hex>` — write bytes to device memory / 写字节到设备内存
- `exec <file>` — send binary file to code_slot and execute / 发送二进制文件到代码槽并执行

### Serial mode / 串口模式

```bash
python ai_host.py --port COM3 --baud 115200
```

### Hosted mode testing / 宿主模式测试

```powershell
# Build the hosted seed / 构建宿主种子
llvm-link seed\tier0_mcu\seed.ll seed\tier3_hosted\seed.ll -o build\seed.bc

# Run with lli / 用 lli 运行
lli build\seed.bc
```

Note: for bidirectional stdio testing, use a named pipe or TCP bridge.
注意：双向 stdio 测试需要命名管道或 TCP 桥接。

## Protocol Reference / 协议参考

```
Sync word / 同步字: 0xAA 0x55 (precedes every message / 每条消息前都有)

HOST → DEVICE / 上位机 → 设备:
  [0xAA 0x55][1B opcode][4B length][payload]
  opcodes / 操作码: 0x01=EXEC  0x02=PEEK  0x03=POKE  0x04=INFO

DEVICE → HOST / 设备 → 上位机:
  [0xAA 0x55][1B status][4B length][data]
  status / 状态: 0x00=OK  0xFE=unknown opcode / 未知操作码
```
