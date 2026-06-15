"""
IRVibeOS Host — TALK protocol + AI integration.
IRVibeOS 上位机 — TALK 协议 + AI 集成。

Speaks the TALK protocol (sync + opcode framing) to an IRVibeOS seed
over serial or stdin/stdout pipe, and can invoke AI to generate LLVM IR.
通过串口或 stdin/stdout 管道与 IRVibeOS 种子通信（TALK 协议：同步字 + 操作码帧），
并可调用 AI 生成 LLVM IR。

Usage / 用法:
  Serial / 串口:  python ai_host.py --port COM3 --baud 115200
  Pipe / 管道:    python ai_host.py --stdio

  AI integration / AI 集成:
    --ai openai --api-base https://api.openai.com/v1 --api-key sk-...
    --ai claude --api-key sk-ant-...
    --ai openai-compatible --api-base http://localhost:11434/v1  (e.g. Ollama)

Interactive commands / 交互命令:
  info              — query device identity / 查询设备身份
  peek <addr> <len> — read device memory (hex addr) / 读设备内存（十六进制地址）
  poke <addr> <hex> — write bytes to device memory / 写字节到设备内存
  exec <file>       — send binary file to code_slot and execute / 发送并执行二进制文件
  vibe <intent>     — ask AI to generate IR for intent and load it / 让 AI 为意图生成 IR 并加载
  compile <ll_file> — compile .ll to native code and send / 编译 .ll 为原生代码并发送
  quit              — exit / 退出
"""

import sys
import struct
import argparse
import subprocess
import tempfile
import os
from pathlib import Path

# Allow running as `python host/ai_host.py` from repo root.
_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from host.vibe.protocol import VibeProtocol  # noqa: E402
from host.vibe.providers import create_provider  # noqa: E402

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


def compile_ir_to_native(ir_text, target_triple='x86_64-unknown-linux-gnu'):
    """Compile LLVM IR to native machine code. / 将 LLVM IR 编译为原生机器码。

    Returns bytes of position-independent native code, or None on error.
    返回位置无关的原生代码字节，失败时返回 None。
    """
    with tempfile.NamedTemporaryFile(mode='w', suffix='.ll', delete=False) as f_ll:
        f_ll.write(ir_text)
        ll_path = f_ll.name

    obj_path = ll_path.replace('.ll', '.o')
    bin_path = ll_path.replace('.ll', '.bin')

    try:
        # Compile IR to object file / 编译 IR 为目标文件
        result = subprocess.run(
            ['llc', '-filetype=obj', f'-mtriple={target_triple}', ll_path, '-o', obj_path],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            print(f"llc error: {result.stderr}")
            return None

        # Extract .text section as raw binary / 提取 .text 段为原始二进制
        # For simplicity, just use the object file directly if small
        # In production, link and extract the code section properly
        # 为简化，小对象文件可直接用；生产环境应正确链接并提取代码段
        with open(obj_path, 'rb') as f:
            native_code = f.read()

        return native_code

    except FileNotFoundError:
        print("Error: llc not found. Install LLVM toolchain.")
        print("错误：未找到 llc。请安装 LLVM 工具链。")
        return None
    except Exception as e:
        print(f"Compilation failed: {e}")
        return None
    finally:
        for path in [ll_path, obj_path, bin_path]:
            if os.path.exists(path):
                os.remove(path)


def make_serial_link(port, baud):
    import serial
    ser = serial.Serial(port, baud, timeout=5)
    return TalkLink(ser.read, ser.write)


def make_stdio_link():
    stdin = sys.stdin.buffer
    stdout = sys.stdout.buffer
    return TalkLink(stdin.read, lambda d: (stdout.write(d), stdout.flush()))


def interactive(link, vibe_protocol=None):
    print("IRVibeOS Host (TALK protocol). Type 'help' for commands.")
    print("IRVibeOS 上位机（TALK 协议）。输入 'help' 查看命令。")

    if vibe_protocol:
        print("AI vibe enabled / AI vibe 已启用")

    while True:
        try:
            line = input("host> ").strip()
        except (EOFError, KeyboardInterrupt):
            break

        if not line:
            continue

        parts = line.split(maxsplit=1)
        cmd = parts[0].lower()

        if cmd == 'help':
            print("  info                  — device identity / 设备身份")
            print("  peek <hex_addr> <len> — read memory / 读内存")
            print("  poke <hex_addr> <hex> — write memory / 写内存")
            print("  exec <file>           — execute binary / 执行二进制")
            print("  compile <ll_file>     — compile .ll and send / 编译 .ll 并发送")
            if vibe_protocol:
                print("  vibe <intent>         — AI generates IR and loads / AI 生成 IR 并加载")
            print("  quit                  — exit / 退出")

        elif cmd == 'info':
            name, slot = link.info()
            if name:
                print(f"  Device / 设备: {name}")
                print(f"  Code slot / 代码槽: {slot} bytes")
            else:
                print("  FAULT / 故障")

        elif cmd == 'peek' and len(parts) >= 2:
            args = parts[1].split()
            if len(args) >= 2:
                addr = int(args[0], 16)
                length = int(args[1])
                data = link.peek(addr, length)
                if data is not None:
                    print(f"  {data.hex()}")
                else:
                    print("  FAULT / 故障")

        elif cmd == 'poke' and len(parts) >= 2:
            args = parts[1].split()
            if len(args) >= 2:
                addr = int(args[0], 16)
                data = bytes.fromhex(args[1])
                ok = link.poke(addr, data)
                print("  OK / 成功" if ok else "  FAULT / 故障")

        elif cmd == 'exec' and len(parts) >= 2:
            filepath = parts[1]
            try:
                with open(filepath, 'rb') as f:
                    code = f.read()
                result = link.exec_code(code)
                if result is not None:
                    print(f"  Result / 结果: {result} (0x{result:08x})")
                else:
                    print("  FAULT / 故障")
            except FileNotFoundError:
                print(f"  File not found / 文件未找到: {filepath}")

        elif cmd == 'compile' and len(parts) >= 2:
            ll_file = parts[1]
            try:
                with open(ll_file, 'r') as f:
                    ir_text = f.read()
                print("  Compiling / 编译中...")
                native = compile_ir_to_native(ir_text)
                if native:
                    print(f"  Compiled {len(native)} bytes, executing / 编译 {len(native)} 字节，执行中...")
                    result = link.exec_code(native)
                    if result is not None:
                        print(f"  Result / 结果: {result} (0x{result:08x})")
                    else:
                        print("  FAULT / 故障")
                else:
                    print("  Compilation failed / 编译失败")
            except FileNotFoundError:
                print(f"  File not found / 文件未找到: {ll_file}")

        elif cmd == 'vibe' and len(parts) >= 2:
            if not vibe_protocol:
                print("  AI not configured. Use --ai option. / AI 未配置。使用 --ai 选项。")
                continue

            intent = parts[1]
            print(f"  Vibing: {intent}")
            print("  Generating IR (with verify+repair) / 生成 IR 中（含验证+修复）...")

            try:
                vibe_result = vibe_protocol.vibe(intent)

                if not vibe_result.success:
                    print(f"  Generation failed: {vibe_result.errors[-1]}")
                    print(f"  生成失败：{vibe_result.errors[-1]}")
                    continue

                print(f"  Generated OK ({vibe_result.attempts} attempt(s))")
                print("\n--- Generated IR ---")
                print(vibe_result.ir_text)
                print("--- End IR ---\n")

                print("  Compiling / 编译中...")
                native = compile_ir_to_native(vibe_result.ir_text)

                if native:
                    print(f"  Compiled {len(native)} bytes, executing / 编译 {len(native)} 字节，执行中...")
                    result = link.exec_code(native)
                    if result is not None:
                        print(f"  Result / 结果: {result} (0x{result:08x})")
                    else:
                        print("  FAULT / 故障")
                else:
                    print("  Compilation failed / 编译失败")

            except Exception as e:
                print(f"  Error / 错误: {e}")

        elif cmd in ('quit', 'exit', 'q'):
            break

        else:
            print(f"  Unknown command / 未知命令: {cmd}")


def main():
    parser = argparse.ArgumentParser(description='IRVibeOS TALK host with AI integration')
    parser.add_argument('--port', help='Serial port (e.g., COM3, /dev/ttyUSB0)')
    parser.add_argument('--baud', type=int, default=115200)
    parser.add_argument('--stdio', action='store_true', help='Use stdin/stdout')

    parser.add_argument('--ai', choices=['openai', 'claude', 'openai-compatible'],
                       help='AI provider / AI 提供商')
    parser.add_argument('--api-key', help='API key / API 密钥')
    parser.add_argument('--api-base', help='API base URL (for OpenAI-compatible) / API 基础 URL（OpenAI 兼容）')
    parser.add_argument('--model', help='Model name / 模型名称')

    args = parser.parse_args()

    # Setup link / 设置连接
    if args.stdio:
        link = make_stdio_link()
    elif args.port:
        link = make_serial_link(args.port, args.baud)
    else:
        parser.print_help()
        sys.exit(1)

    # Setup vibe protocol / 设置 vibe 协议
    vibe_protocol = None
    if args.ai:
        try:
            provider = create_provider(
                args.ai, api_key=args.api_key, model=args.model, api_base=args.api_base
            )
            vibe_protocol = VibeProtocol(provider, max_retries=3, verbose=True)
        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)

    interactive(link, vibe_protocol)


if __name__ == '__main__':
    main()
