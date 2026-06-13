"""
IRVibeOS Host — TALK protocol implementation.
IRVibeOS 上位机 — TALK 协议实现。

Speaks the TALK protocol (sync + opcode framing) to an IRVibeOS seed
over serial or stdin/stdout pipe.
通过串口或 stdin/stdout 管道与 IRVibeOS 种子通信（TALK 协议：同步字 + 操作码帧）。

Usage / 用法:
  Serial / 串口:  python ai_host.py --port COM3 --baud 115200
  Pipe / 管道:    python ai_host.py --stdio

Interactive commands / 交互命令:
  info              — query device identity / 查询设备身份
  peek <addr> <len> — read device memory (hex addr) / 读设备内存（十六进制地址）
  poke <addr> <hex> — write bytes to device memory / 写字节到设备内存
  exec <file>       — send binary file to code_slot and execute / 发送并执行二进制文件
  quit              — exit / 退出
"""

import sys
import struct
import argparse

SYNC = b'\xAA\x55'
OP_EXEC = 1
OP_PEEK = 2
OP_POKE = 3
OP_INFO = 4


class TalkLink:
    """Framed TALK protocol over a byte stream.
    基于字节流的 TALK 协议帧处理。"""

    def __init__(self, read_fn, write_fn):
        self._read = read_fn
        self._write = write_fn

    def _recv_exact(self, n):
        buf = b''
        while len(buf) < n:
            chunk = self._read(n - len(buf))
            if not chunk:
                raise IOError("Connection closed")
            buf += chunk
        return buf

    def _wait_sync(self):
        """Scan for 0xAA 0x55 sync word. / 扫描 0xAA 0x55 同步字。"""
        state = 0
        while True:
            b = self._recv_exact(1)
            if state == 0 and b == b'\xAA':
                state = 1
            elif state == 1 and b == b'\x55':
                return
            else:
                state = 0

    def _send(self, opcode, payload=b''):
        frame = SYNC + bytes([opcode]) + struct.pack('<I', len(payload)) + payload
        self._write(frame)

    def _recv_response(self):
        self._wait_sync()
        status = self._recv_exact(1)[0]
        length = struct.unpack('<I', self._recv_exact(4))[0]
        data = self._recv_exact(length) if length > 0 else b''
        return status, data

    def info(self):
        self._send(OP_INFO)
        status, data = self._recv_response()
        if status != 0:
            return None, None
        name = data[:32].rstrip(b'\x00').decode('ascii', errors='replace')
        slot_size = struct.unpack('<I', data[32:36])[0] if len(data) >= 36 else 0
        return name, slot_size

    def peek(self, addr, length):
        payload = struct.pack('<QI', addr, length)
        self._send(OP_PEEK, payload)
        status, data = self._recv_response()
        if status != 0:
            return None
        return data

    def poke(self, addr, data_bytes):
        payload = struct.pack('<QI', addr, len(data_bytes)) + data_bytes
        self._send(OP_POKE, payload)
        status, _ = self._recv_response()
        return status == 0

    def exec_code(self, code_bytes):
        payload = struct.pack('<I', len(code_bytes)) + code_bytes
        self._send(OP_EXEC, payload)
        status, data = self._recv_response()
        if status != 0:
            return None
        return struct.unpack('<I', data[:4])[0] if len(data) >= 4 else 0


def make_serial_link(port, baud):
    import serial
    ser = serial.Serial(port, baud, timeout=5)
    return TalkLink(ser.read, ser.write)


def make_stdio_link():
    stdin = sys.stdin.buffer
    stdout = sys.stdout.buffer
    return TalkLink(stdin.read, lambda d: (stdout.write(d), stdout.flush()))


def interactive(link):
    print("IRVibeOS Host (TALK protocol). Type 'help' for commands.")
    while True:
        try:
            line = input("host> ").strip()
        except (EOFError, KeyboardInterrupt):
            break

        if not line:
            continue

        parts = line.split()
        cmd = parts[0].lower()

        if cmd == 'help':
            print("  info              — device identity")
            print("  peek <hex_addr> <len> — read memory")
            print("  poke <hex_addr> <hex_bytes> — write memory")
            print("  exec <file>       — execute binary file")
            print("  quit              — exit")

        elif cmd == 'info':
            name, slot = link.info()
            if name:
                print(f"  Device: {name}")
                print(f"  Code slot: {slot} bytes")
            else:
                print("  FAULT")

        elif cmd == 'peek' and len(parts) >= 3:
            addr = int(parts[1], 16)
            length = int(parts[2])
            data = link.peek(addr, length)
            if data is not None:
                print(f"  {data.hex()}")
            else:
                print("  FAULT")

        elif cmd == 'poke' and len(parts) >= 3:
            addr = int(parts[1], 16)
            data = bytes.fromhex(parts[2])
            ok = link.poke(addr, data)
            print("  OK" if ok else "  FAULT")

        elif cmd == 'exec' and len(parts) >= 2:
            try:
                with open(parts[1], 'rb') as f:
                    code = f.read()
                result = link.exec_code(code)
                if result is not None:
                    print(f"  Result: {result} (0x{result:08x})")
                else:
                    print("  FAULT")
            except FileNotFoundError:
                print(f"  File not found: {parts[1]}")

        elif cmd in ('quit', 'exit', 'q'):
            break

        else:
            print(f"  Unknown: {line}")


def main():
    parser = argparse.ArgumentParser(description='IRVibeOS TALK host')
    parser.add_argument('--port', help='Serial port (e.g., COM3, /dev/ttyUSB0)')
    parser.add_argument('--baud', type=int, default=115200)
    parser.add_argument('--stdio', action='store_true', help='Use stdin/stdout')
    args = parser.parse_args()

    if args.stdio:
        link = make_stdio_link()
    elif args.port:
        link = make_serial_link(args.port, args.baud)
    else:
        parser.print_help()
        sys.exit(1)

    interactive(link)


if __name__ == '__main__':
    main()
