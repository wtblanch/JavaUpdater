[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "$PSScriptRoot\JavaUpdateLog.csv"
)

# Elevate if needed
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Get-InstalledJavaVersions {
    $javaVersions = @()
    
    # Check for JDK installations
    $jdkPaths = @(
        "HKLM:\SOFTWARE\JavaSoft\Java Development Kit",
        "HKLM:\SOFTWARE\JavaSoft\JDK"
    )
    
    foreach ($path in $jdkPaths) {
        if (Test-Path $path) {
            $versions = Get-ChildItem $path
            foreach ($version in $versions) {
                $javaHome = (Get-ItemProperty -Path "$($version.PSPath)\$($version.PSChildName)").JavaHome
                if ($javaHome) {
                    $javaExe = Join-Path $javaHome "bin\java.exe"
                    if (Test-Path $javaExe) {
                        $versionInfo = & $javaExe -version 2>&1
                        $versionString = $versionInfo[0] -replace '.*version "([^"]+)".*', '$1'
                        $javaVersions += @{
                            Type = "JDK"
                            Version = $versionString
                            Path = $javaHome
                        }
                    }
                }
            }
        }
    }
    
    # Check for JRE installations
    $jrePaths = @(
        "HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment",
        "HKLM:\SOFTWARE\JavaSoft\JRE"
    )
    
    foreach ($path in $jrePaths) {
        if (Test-Path $path) {
            $versions = Get-ChildItem $path
            foreach ($version in $versions) {
                $javaHome = (Get-ItemProperty -Path "$($version.PSPath)\$($version.PSChildName)").JavaHome
                if ($javaHome) {
                    $javaExe = Join-Path $javaHome "bin\java.exe"
                    if (Test-Path $javaExe) {
                        $versionInfo = & $javaExe -version 2>&1
                        $versionString = $versionInfo[0] -replace '.*version "([^"]+)".*', '$1'
                        $javaVersions += @{
                            Type = "JRE"
                            Version = $versionString
                            Path = $javaHome
                        }
                    }
                }
            }
        }
    }
    
    return $javaVersions
}

function Get-LatestMicrosoftOpenJDK {
    param (
        [Parameter(Mandatory = $false)]
        [string]$Type = "jdk" # can be "jdk" or "jre"
    )
    
    $page = Invoke-WebRequest -Uri "https://learn.microsoft.com/en-us/java/openjdk/download" -UseBasicParsing
    $pattern = if ($Type -eq "jdk") {
        'https:\/\/aka\.ms\/[^"]*jdk-(\d+).*?windows-x64\.msi'
    } else {
        'https:\/\/aka\.ms\/[^"]*jre-(\d+).*?windows-x64\.msi'
    }
    $matches = [regex]::Matches($page.Content, $pattern)
    if ($matches.Count -gt 0) {
        $latest = $matches | Sort-Object { [int]$_.Groups[1].Value } -Descending | Select-Object -First 1
        return $latest.Value
    }
    return $null
}

function Install-Java {
    param (
        [string]$InstallerUrl,
        [string]$Type = "jdk"
    )
    $tempPath = "$env:TEMP\msopenjdk_$Type.msi"
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $tempPath -UseBasicParsing
    Start-Process "msiexec.exe" -ArgumentList "/i `"$tempPath`" /quiet /norestart" -Wait
    Remove-Item $tempPath -Force
}

function Set-JavaHome {
    $jdkPath = Get-ChildItem "$env:ProgramFiles\Microsoft" -Directory | Where-Object { $_.Name -like "jdk*" } | Sort-Object Name -Descending | Select-Object -First 1
    if ($jdkPath) {
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkPath.FullName, [System.EnvironmentVariableTarget]::Machine)
        $env:Path += ";$($jdkPath.FullName)\bin"
    }
}

function Remove-OldJDKs {
    $dirs = Get-ChildItem "$env:ProgramFiles\Microsoft" -Directory | Where-Object { $_.Name -like "jdk*" }
    if ($dirs.Count -gt 1) {
        $newest = $dirs | Sort-Object Name -Descending | Select-Object -First 1
        $old = $dirs | Where-Object { $_.FullName -ne $newest.FullName }
        foreach ($dir in $old) {
            try {
                Remove-Item -Path $dir.FullName -Recurse -Force
            } catch {
                Write-Warning "Could not remove $($dir.FullName): $_"
            }
        }
    }
}

function Is-JavaRunning {
    $procs = Get-Process java -ErrorAction SilentlyContinue
    return $procs -ne $null
}

function Log-Update {
    param (
        [string]$Status,
        [string]$CurrentVersion,
        [string]$UpdatedVersion
    )
    $logLine = [PSCustomObject]@{
        Timestamp       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Status          = $Status
        Installed       = $CurrentVersion
        UpdatedTo       = $UpdatedVersion
        ComputerName    = $env:COMPUTERNAME
    }
    $logExists = Test-Path $LogFile
    $logLine | Export-Csv -Path $LogFile -Append -NoTypeInformation -Force
}

# Main script execution
try {
    # Check and log installed Java versions
    Write-Host "Checking installed Java versions..."
    $installedVersions = Get-InstalledJavaVersions
    if ($installedVersions.Count -gt 0) {
        Write-Host "Currently installed Java versions:"
        foreach ($version in $installedVersions) {
            Write-Host "- $($version.Type) $($version.Version) at $($version.Path)"
        }
    } else {
        Write-Host "No Java installations found. This script is designed to update existing Java installations only."
        Write-Host "Please install Java first before running this update script."
        exit 0
    }

    $currentJDK = Get-InstalledJavaVersions | Where-Object { $_.Type -eq "JDK" } | Select-Object -ExpandProperty Version
    $currentJRE = Get-InstalledJavaVersions | Where-Object { $_.Type -eq "JRE" } | Select-Object -ExpandProperty Version
    
    $latestJDKUrl = Get-LatestMicrosoftOpenJDK -Type "jdk"
    $latestJREUrl = Get-LatestMicrosoftOpenJDK -Type "jre"

    if (-not $latestJDKUrl -or -not $latestJREUrl) {
        Write-Error "Could not fetch latest Microsoft JDK/JRE URLs."
        Log-Update -Status "Failed - No URL" -CurrentVersion "$currentJDK/$currentJRE" -UpdatedVersion "N/A"
        exit 1
    }

    if (Is-JavaRunning) {
        Write-Host "Java is currently running. Please close Java applications before update."
        Log-Update -Status "Skipped - Java in use" -CurrentVersion "$currentJDK/$currentJRE" -UpdatedVersion "N/A"
        exit 1
    }

    $updated = $false
    if (-not $currentJDK -or $latestJDKUrl -notmatch $currentJDK) {
        Write-Host "Installing or updating Java JDK..."
        Install-Java -InstallerUrl $latestJDKUrl -Type "jdk"
        $updated = $true
    }

    if (-not $currentJRE -or $latestJREUrl -notmatch $currentJRE) {
        Write-Host "Installing or updating Java JRE..."
        Install-Java -InstallerUrl $latestJREUrl -Type "jre"
        $updated = $true
    }

    if ($updated) {
        Set-JavaHome
        Remove-OldJDKs
        
        $newJDK = Get-InstalledJavaVersions | Where-Object { $_.Type -eq "JDK" } | Select-Object -ExpandProperty Version
        $newJRE = Get-InstalledJavaVersions | Where-Object { $_.Type -eq "JRE" } | Select-Object -ExpandProperty Version
        
        Write-Host "Java updated to JDK: $newJDK, JRE: $newJRE"
        Log-Update -Status "Updated" -CurrentVersion "$currentJDK/$currentJRE" -UpdatedVersion "$newJDK/$newJRE"
    } else {
        Write-Host "Java is up to date: JDK: $currentJDK, JRE: $currentJRE"
        Log-Update -Status "Already Up To Date" -CurrentVersion "$currentJDK/$currentJRE" -UpdatedVersion "$currentJDK/$currentJRE"
    }
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}
