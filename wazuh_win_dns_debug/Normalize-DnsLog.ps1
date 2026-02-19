# ==============================================================================
# Normalize-DnsLog.ps1
# Converts DNS wire format labels into readable FQDN format
# e.g. (5)ctldl(13)windowsupdate(3)com(0) -> ctldl.windowsupdate.com
#
# Processes all dns_*_done.log files in InputDir and deletes raw files after processing.
#
# Scheduled Task: every 15 minutes, 2 minute offset to Rotate-DnsLog.ps1
# powershell.exe -ExecutionPolicy Bypass -File "C:\dns_debug\Normalize-DnsLog.ps1"
#
# Wazuh ossec.conf:
#   <localfile>
#     <log_format>syslog</log_format>
#     <location>C:\dns_debug\output\dns_normalized_*.log</location>
#   </localfile>
# ==============================================================================

param(
    [string]$InputDir    = "C:\dns_debug",
    [string]$OutputDir   = "C:\dns_debug\output",
    [int]   $KeepMinutes = 60
)

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile    = Join-Path $ScriptDir "Normalize-DnsLog_run.log"
$ServerName = $env:COMPUTERNAME

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry
}

function Convert-DnsWireFormat {
    param([string]$line)

    $wirePattern = '(\(\d+\)[a-zA-Z0-9\-]+)+\(\d+\)'

    if ($line -match $wirePattern) {
        $wirePart = $matches[0]

        $fqdn = ([regex]::Matches($wirePart, '\((\d+)\)([a-zA-Z0-9\-]+)') |
                ForEach-Object { $_.Groups[2].Value }) -join '.'

        $line = $line -replace [regex]::Escape($wirePart), $fqdn
    }

    return $line
}

# --- Create output folder if it does not exist --------------------------------
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Log "Output folder created: $OutputDir"
}

Write-Log "Starting normalization..."

# --- Determine the currently active log file (must not be touched) ------------
try {
    $dnsDiag       = Get-DnsServerDiagnostics -ComputerName $ServerName
    $activeLogFile = $dnsDiag.LogFilePath
    Write-Log "Actively written file (will be skipped): $activeLogFile"
}
catch {
    Write-Log "DNS diagnostics could not be read: $_" "ERROR"
    exit 1
}

# --- Process all dns_*_done.log files -----------------------------------------
$logFiles = Get-ChildItem -Path $InputDir -Filter "dns_*_done.log"

if ($logFiles.Count -eq 0) {
    Write-Log "No log files found to process."
    exit 0
}

Write-Log "$($logFiles.Count) file(s) to process."

foreach ($file in $logFiles) {
    Write-Log "Processing: $($file.Name)"
    try {
        $lines = Get-Content $file.FullName
        $total = $lines.Count

        if ($total -eq 0) {
            Write-Log "$($file.Name) is empty, deleting."
            Remove-Item $file.FullName -Force
            continue
        }

        $converted = 0

        $result = $lines | ForEach-Object {
            $newLine = Convert-DnsWireFormat $_
            if ($newLine -ne $_) { $converted++ }
            $newLine
        }

        $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputFile = Join-Path $OutputDir "dns_normalized_$timestamp.log"

        $result | Set-Content $OutputFile -Encoding UTF8
        Write-Log "Done: $total lines processed, $converted converted -> $($OutputFile | Split-Path -Leaf)"

        Remove-Item $file.FullName -Force
        Write-Log "Raw file deleted: $($file.Name)"
    }
    catch {
        Write-Log "Error processing $($file.Name): $_" "ERROR"
    }
}

# --- Clean up old output files ------------------------------------------------
Write-Log "Cleaning up output files older than $KeepMinutes minutes..."

$cutoff  = (Get-Date).AddMinutes(-$KeepMinutes)
$deleted = 0

Get-ChildItem -Path $OutputDir -Filter "dns_normalized_*.log" |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object {
        try {
            Remove-Item $_.FullName -Force
            Write-Log "Deleted: $($_.Name)"
            $deleted++
        }
        catch {
            Write-Log "Could not delete: $($_.Name) - $_" "WARN"
        }
    }

Write-Log "Cleanup complete. $deleted file(s) deleted."
exit 0