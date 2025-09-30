# Define possible module paths to try and label their source
$ModulePaths = @(
    @{ Path = "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\WorkMode.psm1"; Source = 'default user module directory' },
    @{ Path = (Join-Path $PSScriptRoot '..' '..' 'WorkMode.psm1'); Source = 'project root (repo)' }
)

$ImportSuccess = $false
$ImportedPath = $null
$ImportedSource = $null

foreach ($entry in $ModulePaths) {
    $ModulePath = $entry.Path
    $SourceLabel = $entry.Source

    Write-Host "Trying path ($SourceLabel): $ModulePath"

    if (Test-Path $ModulePath) {
        try {
            Import-Module $ModulePath -Force -ErrorAction Stop
            Write-Host "✅ Successfully imported from ($SourceLabel): $ModulePath"
            $ImportSuccess = $true
            $ImportedPath = $ModulePath
            $ImportedSource = $SourceLabel
            break
        } catch {
            Write-Host "❌ Failed to import from ($SourceLabel) $ModulePath : $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  Path not found ($SourceLabel): $ModulePath" -ForegroundColor Yellow
    }
}

if ($ImportSuccess) {
    Write-Host ''
    Write-Host '---MODULE IMPORT SUCCESS---' -ForegroundColor Green
    Write-Host "Imported from: $ImportedPath" -ForegroundColor Cyan
    Write-Host "Source: $ImportedSource" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '---MODULE CONTENTS---'
    try {
        Get-Command -Module WorkMode | Select-Object Name,CommandType | Format-Table -AutoSize
    } catch {
        Write-Host "Error getting module commands: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host '---WMH-STATUS CHECK---'
    if (Get-Command -Name wmh-status -ErrorAction SilentlyContinue) {
        try {
            wmh-status
        } catch {
            Write-Host "Error running wmh-status: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host 'wmh-status: command not found after import' -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host ''
    Write-Host '---ALL IMPORT ATTEMPTS FAILED---' -ForegroundColor Red
    Write-Host 'Tried the following paths:' -ForegroundColor Yellow
    foreach ($entry in $ModulePaths) {
        Write-Host "  - $($entry.Path)  (source: $($entry.Source))"
    }
    Write-Host ''
    Write-Host 'Please ensure the WorkMode module is properly installed or run this script from the project root directory.' -ForegroundColor Yellow
    exit 2
}