# Test script to check WorkMode.psm1 syntax

# Define possible module paths to try (with labels)
$ModulePaths = @(
    @{ Path = "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\WorkMode.psm1"; Source = 'default user module directory' },
    @{ Path = (Join-Path $PSScriptRoot '..' 'WorkMode.psm1'); Source = 'current project repo root' }
)

$TestSuccess = $false
$TestedPath = $null
$TestedSource = $null

foreach ($entry in $ModulePaths) {
    $ModulePath = $entry.Path
    $SourceLabel = $entry.Source

    Write-Host "Checking syntax for ($SourceLabel): $ModulePath"

    if (Test-Path $ModulePath) {
        try {
            $content = Get-Content -Path $ModulePath -Raw
            $errors = $null
            $tokens = $null

            $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)

            Write-Host "✅ Successfully parsed: $ModulePath" -ForegroundColor Green
            $TestSuccess = $true
            $TestedPath = $ModulePath
            $TestedSource = $SourceLabel

            if ($errors) {
                Write-Host ""
                Write-Host "❌ Syntax errors found in $ModulePath (source: $SourceLabel):" -ForegroundColor Red
                $errors | ForEach-Object {
                    Write-Host "  Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "✅ No syntax errors found in $ModulePath (source: $SourceLabel)" -ForegroundColor Green
            }
            break

        } catch {
            Write-Host "❌ Error parsing $ModulePath (source: $SourceLabel): $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  Path not found ($SourceLabel): $ModulePath" -ForegroundColor Yellow
    }
}

if (-not $TestSuccess) {
    Write-Host ""
    Write-Host "---ALL SYNTAX CHECK ATTEMPTS FAILED---" -ForegroundColor Red
    Write-Host "Tried the following paths:" -ForegroundColor Yellow
    foreach ($entry in $ModulePaths) {
        Write-Host "  - $($entry.Path)  (source: $($entry.Source))"
    }
    Write-Host ""
    Write-Host "Please ensure the WorkMode.psm1 file exists in one of these locations." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host ""
    Write-Host "---SYNTAX CHECK COMPLETED---" -ForegroundColor Cyan
    Write-Host "Tested file: $TestedPath" -ForegroundColor White
    Write-Host "Source: $TestedSource" -ForegroundColor White
}