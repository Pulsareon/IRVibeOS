"""LLVM IR utilities — verification, normalization, and analysis."""

from __future__ import annotations

import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass
class VerifyResult:
    """Result of an llvm-as verification attempt."""

    valid: bool
    error: str = ""


def verify_ir(ir_text: str, *, timeout: int = 30) -> VerifyResult:
    """Verify LLVM IR text with llvm-as.

    Returns a VerifyResult with valid=True if the IR passes, or
    valid=False with the error message from llvm-as.
    """
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", suffix=".ll", delete=False
    ) as tmp:
        tmp.write(ir_text)
        tmp_path = Path(tmp.name)

    bc_path = tmp_path.with_suffix(".bc")
    try:
        result = subprocess.run(
            ["llvm-as", str(tmp_path), "-o", str(bc_path)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
        if result.returncode == 0:
            return VerifyResult(valid=True)
        # Combine stderr (primary) and stdout (sometimes used)
        error = (result.stderr or result.stdout or "unknown error").strip()
        return VerifyResult(valid=False, error=error)
    except FileNotFoundError:
        return VerifyResult(valid=False, error="llvm-as not found in PATH")
    except subprocess.TimeoutExpired:
        return VerifyResult(valid=False, error="llvm-as timed out")
    finally:
        tmp_path.unlink(missing_ok=True)
        bc_path.unlink(missing_ok=True)


def strip_markdown(text: str) -> str:
    """Remove markdown code fences from LLM output."""
    stripped = text.strip()
    if not stripped.startswith("```"):
        return stripped

    lines = stripped.splitlines()
    # Remove opening fence (```llvm, ```ll, ```, etc.)
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    # Remove closing fence
    if lines and lines[-1].strip().startswith("```"):
        lines = lines[:-1]
    return "\n".join(lines).strip() + "\n"


def normalize_ir(text: str) -> str:
    """Clean up IR text: strip markdown, trailing whitespace, ensure final newline."""
    ir = strip_markdown(text)
    # Remove trailing whitespace on each line
    lines = [line.rstrip() for line in ir.splitlines()]
    # Remove excessive blank lines (more than 2 consecutive)
    cleaned = []
    blank_count = 0
    for line in lines:
        if line == "":
            blank_count += 1
            if blank_count <= 2:
                cleaned.append(line)
        else:
            blank_count = 0
            cleaned.append(line)
    return "\n".join(cleaned).strip() + "\n"


def has_main_entry(ir_text: str) -> bool:
    """Check if the IR defines a @main function."""
    return bool(re.search(r"define\s+i32\s+@main\s*\(", ir_text))


def llvm_c_string(text: str) -> tuple[int, str]:
    """Encode a string as an LLVM IR c"..." constant.

    Returns (byte_length, escaped_content) where byte_length includes
    a trailing newline and null terminator.
    """
    data = text.encode("utf-8") + b"\n\x00"
    out = []
    for byte in data:
        if 32 <= byte <= 126 and byte not in (34, 92):
            out.append(chr(byte))
        else:
            out.append(f"\\{byte:02X}")
    return len(data), "".join(out)
