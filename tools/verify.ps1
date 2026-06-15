# IRVibeOS Verification Tool
# Validates all LLVM IR source files.

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "IRVibeOS Source Verification Tool" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

$root = (Get-Location).Path
$irFiles = Get-ChildItem -Recurse -Filter "*.ll" | Where-Object {
    $_.FullName -notmatch "\\(build|build_arm|temp|target|data)\\"
} | Sort-Object FullName

$llvmAs = Get-Command llvm-as -ErrorAction SilentlyContinue
if (-not $llvmAs) {
    Write-Host "ERROR: llvm-as was not found in PATH." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($irFiles.Count) IR source files" -ForegroundColor Green
Write-Host ""

$stats = @{
    Total = 0
    Valid = 0
    Invalid = 0
    Issues = @()
}
$projectIssues = @()

foreach ($file in $irFiles) {
    $stats.Total++
    $relativePath = $file.FullName.Replace($root + "\", "")
    $issues = @()

    Write-Host "Checking: $relativePath" -ForegroundColor White

    $content = Get-Content $file.FullName -Raw
    if ($null -eq $content -or $content.Length -eq 0) {
        $issues += "Empty IR file"
    } else {
        if ($content -notmatch "^;") {
            $issues += "Missing header comment"
        }

        if ($content -notmatch "(define|declare|@)") {
            $issues += "No declarations, definitions, or globals found"
        }
    }

    $tmpBc = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName() + ".bc")
    try {
        & llvm-as $file.FullName -o $tmpBc 2>&1 | ForEach-Object {
            if ($Verbose) {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
        if ($LASTEXITCODE -ne 0) {
            $issues += "llvm-as failed"
        }
    } finally {
        if (Test-Path $tmpBc) {
            Remove-Item -LiteralPath $tmpBc -Force
        }
    }

    if ($issues.Count -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
        $stats.Valid++
    } else {
        Write-Host "  Issues found:" -ForegroundColor Yellow
        foreach ($issue in $issues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
        $stats.Invalid++
        $stats.Issues += "$relativePath : $($issues -join '; ')"
    }

    Write-Host ""
}

if (Test-Path "modules") {
    $moduleDirs = Get-ChildItem "modules" -Directory | Sort-Object FullName
    foreach ($dir in $moduleDirs) {
        $moduleName = $dir.Name
        $mainPath = Join-Path $dir.FullName "main.ll"
        $depsPath = Join-Path $dir.FullName "deps.txt"

        if (-not (Test-Path $mainPath)) {
            $projectIssues += "modules/$moduleName is missing main.ll"
        }

        if (-not (Test-Path $depsPath)) {
            $projectIssues += "modules/$moduleName is missing deps.txt"
        }
    }
}

Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total files: $($stats.Total)" -ForegroundColor White
Write-Host "Valid:       $($stats.Valid)" -ForegroundColor Green
Write-Host "With issues: $($stats.Invalid)" -ForegroundColor $(if ($stats.Invalid -gt 0) { "Yellow" } else { "White" })
Write-Host "Project issues: $($projectIssues.Count)" -ForegroundColor $(if ($projectIssues.Count -gt 0) { "Yellow" } else { "White" })
Write-Host ""

if ($stats.Invalid -gt 0) {
    Write-Host "Files with issues:" -ForegroundColor Yellow
    foreach ($issue in $stats.Issues) {
        Write-Host "  $issue" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($projectIssues.Count -gt 0) {
    Write-Host "Project issues:" -ForegroundColor Yellow
    foreach ($issue in $projectIssues) {
        Write-Host "  $issue" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($stats.Total -gt 0) {
    $percentage = [math]::Round(($stats.Valid / $stats.Total) * 100, 1)
} else {
    $percentage = 0
}

Write-Host "Success rate: $percentage%" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
Write-Host ""

if ($stats.Invalid -eq 0 -and $projectIssues.Count -eq 0) {
    Write-Host "All IR files passed validation." -ForegroundColor Green
    exit 0
}

Write-Host "Some files have issues (see above)." -ForegroundColor Yellow
exit 1
