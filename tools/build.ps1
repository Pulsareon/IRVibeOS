# IRVibeOS Build Tool
# Compiles all LLVM IR files to the target architecture.

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

$root = (Get-Location).Path

# Discover all source IR files. Generated and build outputs are excluded.
$sources = Get-ChildItem -Recurse -Filter "*.ll" | Where-Object {
    $_.FullName -notmatch "\\(build|build_arm|temp|target|data)\\"
} | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Replace($root + "\", "")
    $output = ($relative -replace "[\\/:]", "_") -replace "\.ll$", ".o"
    @{ Path = $relative; Output = $output }
}

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
