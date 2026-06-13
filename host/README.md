# Host Tools

This directory contains tools that run on the host PC to communicate with IRVibeOS seeds over serial or stdin/stdout pipe.

These are **not** part of the OS — they run on the development machine and speak the TALK protocol to the seed.

## ai_host.py

Reference implementation of the host-side TALK protocol. Connects to the seed and provides:

- `info` — query device identity and code slot size
- `peek <addr> <len>` — read device memory
- `poke <addr> <hex>` — write bytes to device memory
- `exec <file>` — send binary file to code_slot and execute

### Serial mode

```bash
python ai_host.py --port COM3 --baud 115200
```

### Hosted mode testing (seed as a process)

```powershell
# Build the hosted seed
llvm-link seed\tier0_mcu\seed.ll seed\tier3_hosted\seed.ll -o build\seed.bc

# Run seed in one terminal, host in another via named pipe
# Or use --stdio mode with pipe redirection
lli build\seed.bc | python host\ai_host.py --stdio
```

Note: for bidirectional stdio communication, you'll need a tool that creates a pair of pipes or a PTY. On Windows, consider using `socat` or a simple TCP bridge.

## Protocol Reference

```
Sync: 0xAA 0x55 (precedes every message in both directions)

HOST → DEVICE:
  [0xAA 0x55][1B opcode][4B length][payload]
  opcodes: 0x01=EXEC  0x02=PEEK  0x03=POKE  0x04=INFO

DEVICE → HOST:
  [0xAA 0x55][1B status][4B length][data]
  status: 0x00=OK  0xFE=unknown opcode
```
