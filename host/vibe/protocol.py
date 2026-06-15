"""Vibe Protocol — the core generate-verify-repair loop.

This module implements the unified vibe pipeline that both hosted_vibe.py
and ai_host.py use. The protocol is provider-agnostic: any VibeProvider
can be plugged in.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .ir_utils import VerifyResult, has_main_entry, normalize_ir, verify_ir
from .providers import VibeProvider


@dataclass
class VibeResult:
    """Outcome of a vibe attempt."""

    success: bool
    ir_text: str = ""
    attempts: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def summary(self) -> str:
        if self.success:
            return f"OK after {self.attempts} attempt(s)"
        return f"FAILED after {self.attempts} attempt(s): {self.errors[-1] if self.errors else 'unknown'}"


class VibeProtocol:
    """Generate → verify → repair loop.

    Usage:
        provider = create_provider("openai", api_key=..., model=...)
        protocol = VibeProtocol(provider, max_retries=3)
        result = protocol.vibe("print fibonacci up to 100")
        if result.success:
            save(result.ir_text)
    """

    def __init__(self, provider: VibeProvider, *, max_retries: int = 3, verbose: bool = False):
        self.provider = provider
        self.max_retries = max_retries
        self.verbose = verbose

    def vibe(self, intent: str) -> VibeResult:
        """Run the full vibe loop for an intent."""
        result = VibeResult(success=False)

        # --- First generation ---
        result.attempts = 1
        raw = self.provider.generate(intent)
        ir_text = normalize_ir(raw)

        if self.verbose:
            print(f"[vibe] attempt 1: generated {len(ir_text)} bytes")

        # --- Verify + repair loop ---
        for attempt in range(1, self.max_retries + 1):
            vr = verify_ir(ir_text)

            if vr.valid:
                # Additional check: does it have @main?
                if not has_main_entry(ir_text):
                    error = "missing define i32 @main() entry point"
                    result.errors.append(error)
                    if self.verbose:
                        print(f"[vibe] attempt {result.attempts}: {error}")
                    if attempt <= self.max_retries:
                        ir_text = self._try_repair(ir_text, error, result)
                    continue

                result.success = True
                result.ir_text = ir_text
                if self.verbose:
                    print(f"[vibe] verified OK on attempt {result.attempts}")
                return result

            # Verification failed — try repair
            result.errors.append(vr.error)
            if self.verbose:
                print(f"[vibe] attempt {result.attempts} failed: {vr.error[:120]}")

            if attempt <= self.max_retries:
                ir_text = self._try_repair(ir_text, vr.error, result)

        # All retries exhausted
        result.ir_text = ir_text  # Keep last attempt for debugging
        return result

    def _try_repair(self, ir_text: str, error: str, result: VibeResult) -> str:
        """Ask the provider to repair the IR."""
        result.attempts += 1
        if self.verbose:
            print(f"[vibe] requesting repair (attempt {result.attempts})...")
        raw = self.provider.repair(ir_text, error)
        return normalize_ir(raw)
