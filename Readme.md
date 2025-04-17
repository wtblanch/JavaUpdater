
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

