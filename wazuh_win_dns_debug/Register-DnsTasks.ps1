# ==============================================================================
# Register-DnsTasks.ps1
# Registers the two Scheduled Tasks for DNS log rotation and normalization.
#
# Run as Administrator:
# powershell.exe -ExecutionPolicy Bypass -File "C:\dns_debug\Register-DnsTasks.ps1"
# ==============================================================================

# --- Task 1: Rotate - runs at :00, :15, :30, :45 ------------------------------
$actionRotate = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument '-ExecutionPolicy Bypass -NonInteractive -File "C:\dns_debug\Rotate-DnsLog.ps1"'

$triggerRotate = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -Once -At "00:00"

$settingsRotate = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName "DNS Log Rotate" `
    -TaskPath "\DNS\" `
    -Action $actionRotate `
    -Trigger $triggerRotate `
    -Settings $settingsRotate `
    -RunLevel Highest `
    -User "SYSTEM" `
    -Force

Write-Host "Task 'DNS Log Rotate' registered."

# --- Task 2: Normalize - runs at :02, :17, :32, :47 (2 minutes after Rotate) --
$actionNormalize = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument '-ExecutionPolicy Bypass -NonInteractive -File "C:\dns_debug\Normalize-DnsLog.ps1"'

$triggerNormalize = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -Once -At "00:02"

$settingsNormalize = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName "DNS Log Normalize" `
    -TaskPath "\DNS\" `
    -Action $actionNormalize `
    -Trigger $triggerNormalize `
    -Settings $settingsNormalize `
    -RunLevel Highest `
    -User "SYSTEM" `
    -Force

Write-Host "Task 'DNS Log Normalize' registered."
Write-Host ""
Write-Host "Both tasks can be found in Task Scheduler under \DNS\"