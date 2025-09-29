try {
    Import-Module 'C:\Users\swfox\Documents\PowerShell\Modules\WorkMode\WorkMode.psm1' -Force -ErrorAction Stop
    Write-Output '---MODULE CONTENTS---'
    Get-Command -Module WorkMode | Select-Object Name,CommandType | Format-Table -AutoSize
    Write-Output '---WMH-STATUS CHECK---'
    if (Get-Command -Name wmh-status -ErrorAction SilentlyContinue) {
        wmh-status
    } else {
        Write-Output 'wmh-status: not found'
    }
} catch {
    Write-Output '---IMPORT ERROR---'
    Write-Output $_.Exception.Message
    exit 1
}