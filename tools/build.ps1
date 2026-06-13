# IRVibeOS Build Tool
# Compiles all IR files to target architecture

param(
    [string]$Target = "x86_64-pc-windows-msvc",
    [string]$OutputDir = "build",
    [switch]$Clean,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "IRVibeOS Build Tool" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""

# Clean build directory if requested
if ($Clean -and (Test-Path $OutputDir)) {
    Write-Host "Cleaning $OutputDir..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $OutputDir
}

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "Target: $Target" -ForegroundColor Green
Write-Host "Output: $OutputDir" -ForegroundColor Green
Write-Host ""

# Define source files with output names
$sources = @(
    @{ Path = "src_ir/irvibeos.ll"; Output = "irvibeos.o" },
    @{ Path = "src_ir/vibe_engine.ll"; Output = "vibe_engine.o" },
    @{ Path = "seed/tier0_mcu/seed.ll"; Output = "seed_tier0.o" },
    @{ Path = "seed/tier3_hosted/seed.ll"; Output = "seed_tier3.o" },
    @{ Path = "modules/hello/main.ll"; Output = "hello_module.o" },
    @{ Path = "examples/hello.ll"; Output = "hello.o" }
)

$success = 0
$failed = 0

foreach ($src in $sources) {
    if (-not (Test-Path $src.Path)) {
        Write-Host "  X $($src.Path) (not found)" -ForegroundColor Red
        $failed++
        continue
    }

    $out = Join-Path $OutputDir $src.Output

    try {
        if ($Verbose) {
            Write-Host "  Compiling $($src.Path)..." -ForegroundColor Gray
        }

        & llc "-mtriple=$Target" -filetype=obj $src.Path -o $out 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            $size = (Get-Item $out).Length
            Write-Host "  OK $($src.Output) ($size bytes)" -ForegroundColor Green
            $success++
        } else {
            Write-Host "  X $($src.Path) (compilation failed)" -ForegroundColor Red
            $failed++
        }
    }
    catch {
        Write-Host "  X $($src.Path) (error: $_)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Summary: $success succeeded, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($failed -eq 0) {
    Write-Host "Build completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Build completed with errors" -ForegroundColor Red
    exit 1
}
