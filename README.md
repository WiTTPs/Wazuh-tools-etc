# Wazuh-tools-etc

A collection of tools, scripts, and configurations for Wazuh SIEM deployments.

---

## 1. `/wazuh_win_dns_debug` — Windows DNS Debug Log Integration

This module collects and normalizes Windows DNS debug logs and forwards them to a Wazuh agent for analysis.
Logging via Microsoft-Windows-DNSServer/Analytical ETW logging channel is currently not supported by Wazuh.
So this is a little workaround that proved to be sufficient for my case.

Technically the DNS debug log gets deactivated for a brief moment whilst rotating the log file, so DNS queries during that time arent being logged.
Luckily this is only a few seconds, so for my use case it was manageable.

Maybe there is a more elegant way in the future.


### Overview

The Windows DNS debug log writes DNS queries and responses in a wire format that is not directly human-readable or parseable by Wazuh. 
This toolset:

1. Rotates the active DNS debug log file every 15 minutes
2. Normalizes DNS wire format labels into readable FQDNs (e.g. `(5)ctldl(13)windowsupdate(3)com(0)` → `ctldl.windowsupdate.com`)
3. Forwards the normalized logs to Wazuh via a wildcard localfile configuration
4. Decodes and creates alerts in Wazuh using a custom decoder and rules

### Requirements

- Windows Server with DNS Server role installed
- PowerShell 5.1 or later
- Wazuh Agent installed on the DNS server
- Wazuh Manager with access to deploy custom decoders and rules

### Folder Structure

```
wazuh_win_dns_debug/
├── Rotate-DnsLog.ps1               # Rotates the active DNS debug log file
├── Normalize-DnsLog.ps1            # Normalizes wire format to readable FQDNs
├── Register-DnsTasks.ps1           # Registers both scripts as Scheduled Tasks
├── 0001_windows_dns_debug_decoder.xml  # Wazuh custom decoder (deploy on Manager)
└── custom_dns_rules.xml            # Wazuh custom rules (deploy on Manager)
```

### How It Works

```
DNS Service
    │
    │  writes dns_TIMESTAMP.log
    ▼
Rotate-DnsLog.ps1  (every 15 min)
    │
    │  copies active log to dns_TIMESTAMP_done.log
    │  restarts DNS logging with new filename
    ▼
Normalize-DnsLog.ps1  (every 15 min, 2 min offset)
    │
    │  converts wire format → FQDN
    │  writes dns_normalized_TIMESTAMP.log to output\
    │  deletes raw _done.log
    ▼
Wazuh Agent
    │
    │  reads output\dns_normalized_*.log
    ▼
Wazuh Manager
    │
    │  decodes and applies rules
    ▼
Wazuh Dashboard
```

### Installation

#### 1. Prepare the DNS server

Create the working directory:
```powershell
New-Item -ItemType Directory -Path "C:\dns_debug\output" -Force
```

Copy the following scripts to `C:\dns_debug\`:
- `Rotate-DnsLog.ps1`
- `Normalize-DnsLog.ps1`
- `Register-DnsTasks.ps1`

#### 2. Enable DNS Debug Logging

Enable DNS debug logging via PowerShell or DNS Manager. The scripts expect logging to be active with at least **Queries**, **Answers**, **TCP** and **UDP** enabled:

```powershell
Set-DnsServerDiagnostics -ComputerName $env:COMPUTERNAME `
    -LogFilePath         "C:\dns_debug\dns_initial.log" `
    -EnableLoggingToFile $true `
    -Queries             $true `
    -Answers             $true `
    -ReceivePackets      $true `
    -SendPackets         $true `
    -TcpPackets          $true `
    -UdpPackets          $true `
    -MaxMBFileSize       10000000
```

#### 3. Register Scheduled Tasks

Run the following as Administrator:
```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\dns_debug\Register-DnsTasks.ps1"
```

This registers two tasks under `\DNS\` in Task Scheduler:
| Task | Schedule |
|------|----------|
| DNS Log Rotate | Every 15 min at :00, :15, :30, :45 |
| DNS Log Normalize | Every 15 min at :02, :17, :32, :47 |

Both tasks run as `SYSTEM`.

#### 4. Configure Wazuh Agent

Add the following to the Wazuh agent configuration (`ossec.conf`):
```xml
<localfile>
  <log_format>syslog</log_format>
  <location>C:\dns_debug\output\dns_normalized_*.log</location>
</localfile>
```

Restart the Wazuh agent:
```powershell
Restart-Service -Name "Wazuh"
```

#### 5. Deploy Decoder and Rules on Wazuh Manager

Copy the decoder and rules to the Wazuh Manager:
```bash
cp 0001_windows_dns_debug_decoder.xml /var/ossec/etc/decoders/
cp custom_dns_rules.xml /var/ossec/etc/rules/
```

Restart the Wazuh Manager:
```bash
systemctl restart wazuh-manager
```

### Log File Lifecycle

| File | Description |
|------|-------------|
| `C:\dns_debug\dns_TIMESTAMP.log` | Active file being written by DNS service |
| `C:\dns_debug\dns_TIMESTAMP_done.log` | Copied and ready for normalization |
| `C:\dns_debug\output\dns_normalized_TIMESTAMP.log` | Normalized output read by Wazuh agent |

Normalized output files are automatically deleted after **60 minutes** (configurable via `-KeepMinutes` parameter).

### Script Parameters

**Rotate-DnsLog.ps1**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-LogDir` | `C:\dns_debug` | Directory for DNS log files |
| `-MaxSize` | `10000000` | Maximum DNS log file size in bytes |

**Normalize-DnsLog.ps1**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-InputDir` | `C:\dns_debug` | Directory containing raw log files |
| `-OutputDir` | `C:\dns_debug\output` | Directory for normalized output files |
| `-KeepMinutes` | `60` | How long to keep normalized files before deletion |




###  To Do:
Whitelisting of Domains. There a some options for that, but I am still testing which is the most efficient way.
