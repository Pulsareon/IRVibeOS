"""Hosted IRVibeOS 1.0 vibe tool.

This tool implements the core vibe loop:
intent -> LLVM IR -> llvm-as verification -> modules/<name>/main.ll -> optional lli run.

Uses the host.vibe package for generation, verification, and repair.
Host tooling is allowed to be Python. System/device source remains LLVM IR.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

# Allow running as `python host/hosted_vibe.py` from repo root.
_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from host.vibe.ir_utils import verify_ir  # noqa: E402
from host.vibe.protocol import VibeProtocol  # noqa: E402
from host.vibe.providers import create_provider  # noqa: E402


MODULE_RE = re.compile(r"^[A-Za-z0-9_-]+$")


def fail(message: str, code: int = 1) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(code)


def run_cmd(
    args: list[str], *, input_text: str | None = None, timeout: int = 60
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        input=input_text,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def require_tool(name: str) -> None:
    try:
        result = run_cmd([name, "--version"], timeout=10)
    except FileNotFoundError:
        fail(f"{name} was not found in PATH")
    if result.returncode != 0:
        fail(f"{name} exists but failed to run: {result.stderr.strip()}")


def save_module(
    modules_dir: Path, name: str, ir_text: str, intent: str, provider: str, force: bool
) -> Path:
    """Save a verified module to the registry."""
    if not MODULE_RE.match(name):
        fail("module name must contain only letters, digits, underscore, or hyphen")

    module_dir = modules_dir / name
    main_path = module_dir / "main.ll"
    deps_path = module_dir / "deps.txt"

    if main_path.exists() and not force:
        fail(f"{main_path} already exists; pass --force to overwrite")

    module_dir.mkdir(parents=True, exist_ok=True)
    main_path.write_text(ir_text, encoding="utf-8")
    deps_path.write_text(
        f"irvibeos.core >= 1.0\nprovider: {provider}\nintent: {intent}\n",
        encoding="utf-8",
    )
    return main_path


def run_module(main_path: Path) -> int:
    """Execute a module with lli."""
    require_tool("lli")
    result = run_cmd(["lli", str(main_path)], timeout=30)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    return result.returncode


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a hosted IRVibeOS module from an intent."
    )
    parser.add_argument("--name", required=True, help="module name under modules/")
    parser.add_argument("--intent", required=True, help="intent to implement")
    parser.add_argument(
        "--provider",
        choices=["template", "openai", "openai-compatible", "claude"],
        default="template",
        help="generation provider; template is offline and deterministic",
    )
    parser.add_argument("--api-key", help="API key for AI providers")
    parser.add_argument("--api-base", help="OpenAI-compatible API base URL")
    parser.add_argument("--model", help="AI model name")
    parser.add_argument("--modules-dir", default="modules", help="module registry directory")
    parser.add_argument("--force", action="store_true", help="overwrite an existing module")
    parser.add_argument("--run", action="store_true", help="run the module with lli after saving")
    parser.add_argument("--print-ir", action="store_true", help="print generated IR")
    parser.add_argument(
        "--retries", type=int, default=3, help="max repair attempts on verification failure"
    )
    parser.add_argument("--verbose", action="store_true", help="show generation/repair details")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo_root = Path.cwd()
    modules_dir = (repo_root / args.modules_dir).resolve()

    require_tool("llvm-as")

    # Create provider and protocol
    try:
        provider = create_provider(
            args.provider,
            api_key=args.api_key,
            model=args.model,
            api_base=args.api_base,
        )
    except ValueError as e:
        fail(str(e))

    protocol = VibeProtocol(provider, max_retries=args.retries, verbose=args.verbose)

    # Run the vibe loop
    result = protocol.vibe(args.intent)

    if not result.success:
        fail(f"generation failed after {result.attempts} attempts: {result.errors[-1]}")

    if args.print_ir:
        print(result.ir_text)

    main_path = save_module(
        modules_dir, args.name, result.ir_text, args.intent, args.provider, args.force
    )
    print(f"Saved module: {main_path} ({result.attempts} attempt(s))")

    if args.run:
        return run_module(main_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
