# ==============================================================================
# Rotate-DnsLog.ps1
# Disables DNS debug logging and restarts it with a new timestamped filename.
# Copies the current log file before rotation so Normalize-DnsLog.ps1 can process it.
#
# Scheduled Task: every 15 minutes
# powershell.exe -ExecutionPolicy Bypass -File "C:\dns_debug\Rotate-DnsLog.ps1"
# ==============================================================================

param(
    [string]$LogDir  = "C:\dns_debug",
    [int]   $MaxSize = 10000000
)

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile    = Join-Path $ScriptDir "Rotate-DnsLog_run.log"
$ServerName = $env:COMPUTERNAME

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry
}

Write-Log "Starting DNS log rotation... (Server: $ServerName)"

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$newLogFile = Join-Path $LogDir "dns_$timestamp.log"

# --- Copy current log file so Normalize-DnsLog.ps1 can find and process it ---
try {
    $dnsDiag   = Get-DnsServerDiagnostics -ComputerName $ServerName
    $activeLog = $dnsDiag.LogFilePath

    if ($activeLog -and (Test-Path $activeLog)) {
        $copyName = ($activeLog | Split-Path -Leaf) -replace "\.log$", "_done.log"
        $copyPath = Join-Path $LogDir $copyName
        Copy-Item -Path $activeLog -Destination $copyPath -Force
        Write-Log "Active log file copied to: $copyPath ($([math]::Round((Get-Item $copyPath).Length / 1KB)) KB)"
    } else {
        Write-Log "No active log file found."
    }
}
catch {
    Write-Log "Could not copy active log file: $_" "WARN"
}

# --- Disable DNS logging and restart with new filename ------------------------
try {
    Write-Log "Disabling DNS debug logging..."
    Set-DnsServerDiagnostics -All $false -ComputerName $ServerName

    Write-Log "Starting DNS debug logging with new file: $newLogFile"
    Set-DnsServerDiagnostics -ComputerName $ServerName `
        -LogFilePath         $newLogFile `
        -EnableLoggingToFile $true `
        -Queries             $true `
        -Answers             $true `
        -ReceivePackets      $true `
        -SendPackets         $true `
        -TcpPackets          $true `
        -UdpPackets          $true `
        -MaxMBFileSize       $MaxSize

    Write-Log "DNS debug logging is running again, writing to: $newLogFile"
}
catch {
    Write-Log "Error during DNS log rotation: $_" "ERROR"
    exit 1
}

Write-Log "Rotation complete."
exit 0