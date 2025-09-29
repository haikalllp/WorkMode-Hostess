# Test script to check WorkMode.psm1 syntax
$content = Get-Content -Path "E:\CODING\Projects\CODE\WorkMode-Hostess\WorkMode.psm1" -Raw
$errors = $null
$tokens = $null
try {
    $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)
    if ($errors) {
        Write-Host "Syntax errors found:"
        $errors | ForEach-Object {
            Write-Host "Line $($_.Extent.StartLineNumber): $($_.Message)"
        }
    } else {
        Write-Host "No syntax errors found"
    }
} catch {
    Write-Host "Error parsing file: $($_.Exception.Message)"
}