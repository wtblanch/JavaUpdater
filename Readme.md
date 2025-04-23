# Java Distribution Updater for Windows

This repository includes PowerShell scripts to automatically install or update multiple Java distributions (Oracle JDK, OpenJDK, Microsoft Build of OpenJDK) on Windows machines. The update process detects and manages different Java distributions, supporting both local execution and Azure Automation deployment.

## 📁 Files Included

| File | Description |
|------|-------------|
| `Update-Java-Distribution.ps1` | Local script for updating multiple Java distributions with logging and cleanup |
| `Update-Java-Distribution-AzureRunbook.ps1` | Azure Automation Runbook version that logs results to Log Analytics |

## ✅ Features

- Supports multiple Java distributions:
  - Oracle JDK (version 24)
  - Eclipse Adoptium OpenJDK/JRE (version 21.0.6+7)
  - Microsoft Build of OpenJDK
- Automatic detection of installed distributions
- Silent installation and updates
- Comprehensive logging:
  - Local CSV logging
  - Azure Log Analytics integration for runbook version
- Distribution-specific installation paths and configurations
- Cleanup of temporary files
- Error handling and detailed status reporting

## 🖥️ Local Execution

To run the local script:

```powershell
.\Update-Java-Distribution.ps1
```

This will:

- Detect all installed Java distributions
- Update each distribution if needed
- Log results to local CSV file

## ☁️ Azure Automation Setup

1. Import `Update-Java-Distribution-AzureRunbook.ps1` into your Azure Automation account
2. Configure required parameters:

   ```powershell
   Required:
   - WorkspaceId    : Log Analytics Workspace ID
   - SharedKey      : Log Analytics Workspace Primary/Secondary Key
   
   Optional:
   - LogType        : Custom log type (default: JavaUpdateLog)
   - ComputerName   : Target computer name (default: local computer)
   ```

3. Create Automation variables:
   - Create `WorkspaceId` variable with your Log Analytics Workspace ID
   - Create `SharedKey` variable with your Log Analytics Primary Key
4. Schedule the runbook as needed

## 📊 Log Analytics Integration

### Sample KQL Queries

Query all updates in the last 7 days:

```kusto
JavaUpdateLog_CL
| where TimeGenerated > ago(7d)
| project TimeGenerated, Distribution_s, Status_s, CurrentVersion_s, UpdatedVersion_s, ComputerName_s
| order by TimeGenerated desc
```

Find failed updates:

```kusto
JavaUpdateLog_CL
| where Status_s == "Update Failed"
| project TimeGenerated, Distribution_s, ComputerName_s, CurrentVersion_s
```

### Log Schema

```json
{
  "TimeGenerated": "2024-01-20T10:30:00Z",
  "Distribution": "Oracle JDK",
  "Status": "Updated",
  "CurrentVersion": "17.0.9",
  "UpdatedVersion": "24",
  "ComputerName": "DESKTOP-ABC123"
}
```

## 🔄 Supported Java Versions

| Distribution | Latest Version | Download Source |
|--------------|---------------|-----------------|
| Oracle JDK | 24 | Oracle Technology Network |
| OpenJDK/JRE | 21.0.6+7 | Eclipse Adoptium |
| Microsoft JDK | Latest | Microsoft OpenJDK |

## 🛡️ Security Notes

- Scripts require administrative privileges
- Uses HTTPS for all downloads
- Verifies downloads before installation
- Supports both local and domain authentication
- Cleans up temporary files after installation

## 🔍 Troubleshooting

Logs can be found in:

- Local execution: Check `JavaUpdateLog.csv` in script directory
- Azure Runbook: Check Log Analytics under custom logs (`JavaUpdateLog_CL`)

Common issues:

1. Access Denied: Run with administrative privileges
2. Network Issues: Verify connectivity to download sources
3. Installation Failures: Check Windows Event Logs
