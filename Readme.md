<<<<<<< HEAD
# Java Updater Script

This PowerShell script automatically updates Java JDK and JRE installations to the latest version (currently 21.0.6+7) on Windows systems. It can be run locally or remotely on multiple machines.

## Features

- Automatically detects and logs currently installed Java versions (both JDK and JRE)
- Downloads and installs the latest Java version (21.0.6+7)
- Supports both local and remote execution
- Silent installation (no user interaction required)
- Verifies and logs new installations after completion
- Self-elevates to administrator privileges when needed

## Prerequisites

- Windows PowerShell 5.1 or later
- Administrator privileges
- Internet connection for downloading Java installers

## Usage

### Local Installation

```powershell
.\Update-Java.ps1
```

### Remote Installation

```powershell
$cred = Get-Credential
.\Update-Java.ps1 -ComputerName "RemoteComputer" -Credential $cred -Remote
```

## Parameters

- `-ComputerName`: (Optional) Target computer name for remote installation. Defaults to local computer.
- `-Credential`: (Optional) PSCredential object for remote installation.
- `-Remote`: (Switch) Enables remote installation mode.

## Output

The script provides detailed output about:
1. Currently installed Java versions before upgrade
2. Installation progress
3. Verification of new installations after upgrade

Example output:
```
Checking installed Java versions...
Currently installed Java versions:
- JDK 17.0.1 at C:\Program Files\Java\jdk-17.0.1
- JRE 17.0.1 at C:\Program Files\Java\jre-17.0.1

[Installation process...]

Verifying new Java installations...
Current Java versions after installation:
- JDK 21.0.6+7 at C:\Program Files\Java\jdk-21.0.6+7
- JRE 21.0.6+7 at C:\Program Files\Java\jre-21.0.6+7
```

## Notes

- The script uses the following download URLs:
  - JDK: https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_x64_windows_hotspot_21.0.6_7.msi
  - JRE: https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jre_x64_windows_hotspot_21.0.6_7.msi
- Installation is performed silently using MSI
- Temporary files are automatically cleaned up after installation
- The script requires administrator privileges to run

## Error Handling

- The script will stop on any error and provide detailed error messages
- Failed installations will be reported with specific error details
- Network connectivity issues will be clearly indicated

# Microsoft OpenJDK Updater for Windows

This repository includes PowerShell scripts to automatically install or update the **Microsoft Build of OpenJDK** on Windows machines. The update process detects the latest available version from the official Microsoft OpenJDK site and installs it silently.

---

## 📁 Files Included

| File | Description |
|------|-------------|
| `Update-Java-Microsoft.ps1` | Local script for Windows with logging, JAVA_HOME update, and old version cleanup |
| `Update-Java-AzureRunbook.ps1` | Azure Automation Runbook version that logs results to Log Analytics |

---

## ✅ Features

- Automatically fetches latest Microsoft OpenJDK `.msi` installer
- Checks if Java is currently running before upgrade
- Silently installs or upgrades OpenJDK
- Sets `JAVA_HOME` for all users (machine scope)
- Removes old versions after successful update
- Logs update results:
  - To a CSV file (for local script)
  - To Azure Log Analytics (for runbook)
- Detects version from registry or installed folder

---

## 🖥️ How to Run (Locally)

To run the local script even if your execution policy is restrictive:

```powershell
powershell -ExecutionPolicy Bypass -File .\Update-Java-Microsoft-Enhanced.ps1
```

This will:
- Install or upgrade to the latest OpenJDK if needed
- Write logs to `JavaUpdateLog.csv` in the script folder

> 💡 Make sure you run the script **as administrator**.

---

## ☁️ How to Run (Azure Automation)

1. Import `Update-Java-AzureRunbook-Enhanced.ps1` into your Azure Automation Account as a PowerShell Runbook.
2. Provide the following parameters:
   - `WorkspaceId`: Log Analytics Workspace ID
   - `SharedKey`: Primary key for the workspace
   - `LogType`: *(optional)* default is `JavaUpdateLog`
3. Schedule the runbook as needed

The update logs will appear in Azure Monitor under **Custom Logs**.

---

## 🛡️ Note on Execution Policy

These scripts are unsigned by default. You can either:

- Use `-ExecutionPolicy Bypass` for local runs
- Unblock the file manually with:

```powershell
Unblock-File -Path .\Update-Java-Microsoft-Enhanced.ps1
```

---

## 📄 Log Output Format

### Local CSV Example
```csv
Timestamp,Status,Installed,UpdatedTo,ComputerName
2025-04-16 23:14:00,Updated,21.0.5,21.0.6,MY-PC
```

### Azure Log Analytics Example (JavaUpdateLog)
```json
{
  "TimeGenerated": "2025-04-16T23:45:00Z",
  "Status": "Updated",
  "Installed": "21.0.5",
  "UpdatedTo": "21.0.6",
  "ComputerName": "SRV-JAVA01"
}
```

=======

# Microsoft OpenJDK Updater for Windows

This repository includes PowerShell scripts to automatically install or update the **Microsoft Build of OpenJDK** on Windows machines. The update process detects the latest available version from the official Microsoft OpenJDK site and installs it silently.

---

## 📁 Files Included

| File | Description |
|------|-------------|
| `Update-Java-Microsoft-Enhanced.ps1` | Local script for Windows with logging, JAVA_HOME update, and old version cleanup |
| `Update-Java-AzureRunbook-Enhanced.ps1` | Azure Automation Runbook version that logs results to Log Analytics |

---

## ✅ Features

- Automatically fetches latest Microsoft OpenJDK `.msi` installer
- Checks if Java is currently running before upgrade
- Silently installs or upgrades OpenJDK
- Sets `JAVA_HOME` for all users (machine scope)
- Removes old versions after successful update
- Logs update results:
  - To a CSV file (for local script)
  - To Azure Log Analytics (for runbook)
- Detects version from registry or installed folder

---

## 🖥️ How to Run (Locally)

To run the local script even if your execution policy is restrictive:

```powershell
powershell -ExecutionPolicy Bypass -File .\Update-Java-Microsoft-Enhanced.ps1
```

This will:
- Install or upgrade to the latest OpenJDK if needed
- Write logs to `JavaUpdateLog.csv` in the script folder

> 💡 Make sure you run the script **as administrator**.

---

## ☁️ How to Run (Azure Automation)

1. Import `Update-Java-AzureRunbook-Enhanced.ps1` into your Azure Automation Account as a PowerShell Runbook.
2. Provide the following parameters:
   - `WorkspaceId`: Log Analytics Workspace ID
   - `SharedKey`: Primary key for the workspace
   - `LogType`: *(optional)* default is `JavaUpdateLog`
3. Schedule the runbook as needed

The update logs will appear in Azure Monitor under **Custom Logs**.

---

## 🛡️ Note on Execution Policy

These scripts are unsigned by default. You can either:

- Use `-ExecutionPolicy Bypass` for local runs
- Unblock the file manually with:

```powershell
Unblock-File -Path .\Update-Java-Microsoft-Enhanced.ps1
```

---

## 📄 Log Output Format

### Local CSV Example
```csv
Timestamp,Status,Installed,UpdatedTo,ComputerName
2025-04-16 23:14:00,Updated,21.0.5,21.0.6,MY-PC
```

### Azure Log Analytics Example (JavaUpdateLog)
```json
{
  "TimeGenerated": "2025-04-16T23:45:00Z",
  "Status": "Updated",
  "Installed": "21.0.5",
  "UpdatedTo": "21.0.6",
  "ComputerName": "SRV-JAVA01"
}
```

>>>>>>> 51281e38a9fc6f743ff1406ddfffd682f9b00461
