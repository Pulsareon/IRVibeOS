# IRVibeOS Verification Tool
# Validates all IR source files

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  IRVibeOS Source Verification Tool" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Find all .ll files
$irFiles = Get-ChildItem -Recurse -Filter "*.ll" | Where-Object {
    $_.FullName -notmatch "\\(build|temp|target|data)\\"
}

Write-Host "Found $($irFiles.Count) IR source files" -ForegroundColor Green
Write-Host ""

$stats = @{
    Total = 0
    Valid = 0
    Invalid = 0
    Issues = @()
}

foreach ($file in $irFiles) {
    $stats.Total++
    $relativePath = $file.FullName.Replace((Get-Location).Path + "\", "")

    Write-Host "Checking: $relativePath" -ForegroundColor White

    # Check 1: Basic LLVM IR syntax
    $content = Get-Content $file.FullName -Raw

    # Check for common issues
    $issues = @()

    # Check for proper file header
    if ($content -notmatch "^;") {
        $issues += "  ⚠ Missing header comment"
    }

    # Check for define or declare statements
    if ($content -notmatch "(define|declare)") {
        $issues += "  ⚠ No function definitions or declarations found"
    }

    # Check for string constant mismatches (common error)
    $stringMatches = [regex]::Matches($content, '@\w+ = .*constant \[(\d+) x i8\] c"([^"]*)"')
    foreach ($match in $stringMatches) {
        $declaredLen = [int]$match.Groups[1].Value
        $stringContent = $match.Groups[2].Value
        # Count actual characters (accounting for escape sequences)
        $actualContent = $stringContent -replace '\\[0-9a-fA-F]{2}', 'X' -replace '\\..', 'X'
        $actualLen = $actualContent.Length

        if ($actualLen -ne $declaredLen) {
            $issues += "  ✗ String constant length mismatch: declared $declaredLen, actual $actualLen"
        }
    }

    # Check for SSA violations (very basic check)
    if ($content -match "(%\w+)\s*=.*\n[^%]*\1\s*=") {
        $issues += "  ⚠ Possible SSA form violation (variable redefinition)"
    }

    if ($issues.Count -eq 0) {
        Write-Host "  ✓ Valid" -ForegroundColor Green
        $stats.Valid++
    } else {
        Write-Host "  Issues found:" -ForegroundColor Yellow
        foreach ($issue in $issues) {
            Write-Host $issue -ForegroundColor Yellow
        }
        $stats.Invalid++
        $stats.Issues += "$relativePath : $($issues -join '; ')"
    }

    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Verification Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total files:    $($stats.Total)" -ForegroundColor White
Write-Host "Valid:          $($stats.Valid)" -ForegroundColor Green
Write-Host "With issues:    $($stats.Invalid)" -ForegroundColor $(if ($stats.Invalid -gt 0) { "Yellow" } else { "White" })
Write-Host ""

if ($stats.Invalid -gt 0) {
    Write-Host "Files with issues:" -ForegroundColor Yellow
    foreach ($issue in $stats.Issues) {
        Write-Host "  $issue" -ForegroundColor Yellow
    }
    Write-Host ""
}

$percentage = [math]::Round(($stats.Valid / $stats.Total) * 100, 1)
Write-Host "Success rate: $percentage%" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
Write-Host ""

if ($stats.Invalid -eq 0) {
    Write-Host "✓ All IR files passed basic validation!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠ Some files have issues (see above)" -ForegroundColor Yellow
    exit 1
}
