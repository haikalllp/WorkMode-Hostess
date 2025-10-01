# Test script to verify wmh- commands work
Write-Host "Testing WorkMode module commands..." -ForegroundColor Cyan

try {
    # Import the module
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'WorkMode.psm1') -Force -ErrorAction Stop
    Write-Host "✅ Module imported successfully" -ForegroundColor Green

    # Test all wmh- aliases
    $commands = @(
        'wmh-on', 'wmh-off', 'wmh-status', 'wmh-stats', 'wmh-history', 'wmh-clear',
        'wmh-add', 'wmh-remove', 'wmh-list', 'wmh-update', 'wmh-doctor', 'wmh-track',
        'wmh-info', 'wmh-help', 'wmh-uninstall'
    )

    Write-Host "`nTesting aliases:" -ForegroundColor Yellow
    foreach ($cmd in $commands) {
        if (Get-Alias -Name $cmd -ErrorAction SilentlyContinue) {
            Write-Host "✅ $cmd" -ForegroundColor Green
        } else {
            Write-Host "❌ $cmd (not found)" -ForegroundColor Red
        }
    }

    # Show command summary
    Write-Host "`n📊 Command Summary:" -ForegroundColor Cyan
    $aliasCount = (Get-Alias | Where-Object {$_.Name -like 'wmh-*'}).Count
    Write-Host "Total wmh- aliases found: $aliasCount" -ForegroundColor White

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Module has syntax errors that need to be fixed." -ForegroundColor Yellow
}