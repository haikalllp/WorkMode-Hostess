#!/usr/bin/env pwsh

<#
.SYNOPSIS
Runs all test_*.ps1 scripts in the scripts directory.
.DESCRIPTION
Executes each test script in a separate pwsh process, collects exit codes and prints a summary.
.PARAMETER StopOnFailure
If set, stop on first failing test.
.EXAMPLE
.\run-all-tests.ps1
.EXAMPLE
.\run-all-tests.ps1 -StopOnFailure
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$StopOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$pwshCmd = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshCmd) {
    Write-Host "pwsh executable not found in PATH. Ensure PowerShell Core is installed." -ForegroundColor Red
    exit 2
}

$testDir = Join-Path $PSScriptRoot 'tests'
if (-not (Test-Path $testDir)) {
    # fallback to script root if tests subdirectory doesn't exist
    $testDir = $PSScriptRoot
}
$tests = Get-ChildItem -Path $testDir -Filter 'test_*.ps1' -File | Sort-Object Name
if (-not $tests) {
    Write-Host "No test scripts found matching 'test_*.ps1' in $testDir" -ForegroundColor Yellow
    exit 0
}

$results = @()
foreach ($file in $tests) {
    Write-Host "----------------------------------------" -ForegroundColor DarkCyan
    Write-Host "Running: $($file.Name)" -ForegroundColor Cyan
    $start = Get-Date

    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$($file.FullName)`""

    # Create temp files to capture stdout/stderr
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $proc = Start-Process -FilePath $pwshCmd -ArgumentList $args `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile `
            -Wait -PassThru -ErrorAction Stop
        $exit = $proc.ExitCode
    } catch {
        Write-Host "Failed to start process for $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        $exit = 2
    }

    # Read captured output (if any)
    $stdout = ""
    $stderr = ""
    try { if (Test-Path $stdoutFile) { $stdout = Get-Content -Path $stdoutFile -Raw -ErrorAction SilentlyContinue } } catch {}
    try { if (Test-Path $stderrFile) { $stderr = Get-Content -Path $stderrFile -Raw -ErrorAction SilentlyContinue } } catch {}

    # Show captured output when there are errors or stderr content
    if ($exit -ne 0 -or $stderr) {
        if ($stdout) {
            Write-Host "`n--- stdout ($($file.Name)) ---" -ForegroundColor DarkGray
            Write-Host $stdout
        }
        if ($stderr) {
            Write-Host "`n--- stderr ($($file.Name)) ---" -ForegroundColor Yellow
            Write-Host $stderr -ForegroundColor Red
        }
    }

    # Cleanup temp files
    try { Remove-Item -Path $stdoutFile,$stderrFile -ErrorAction SilentlyContinue } catch {}

    $duration = (Get-Date) - $start
    $status = if ($exit -eq 0) {'Passed'} else {'Failed'}
    $color = if ($exit -eq 0) {'Green'} else {'Red'}
    Write-Host "Result: $status (ExitCode: $exit) — ${([math]::Round($duration.TotalSeconds,2))}s" -ForegroundColor $color

    $results += [PSCustomObject]@{
        Name = $file.Name
        Path = $file.FullName
        ExitCode = $exit
        Status = $status
        DurationSeconds = [math]::Round($duration.TotalSeconds,2)
    }

    if ($StopOnFailure -and $exit -ne 0) {
        Write-Host "Stopping on first failure as requested." -ForegroundColor Yellow
        break
    }
}

Write-Host "========================================" -ForegroundColor Cyan
$total = $results.Count
# Force arrays so .Count is always available even when there is 0 or 1 item
$failed = @($results | Where-Object { $_.ExitCode -ne 0 })
$passed = @($results | Where-Object { $_.ExitCode -eq 0 })
Write-Host "Test summary: $($passed.Count) passed, $($failed.Count) failed, $total total" -ForegroundColor White

if ($failed.Count -gt 0) {
    Write-Host "`nFailed tests:" -ForegroundColor Red
    foreach ($f in $failed) {
        Write-Host " - $($f.Name)  ExitCode: $($f.ExitCode)  Duration: $($f.DurationSeconds)s" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`nAll tests passed." -ForegroundColor Green
    exit 0
}