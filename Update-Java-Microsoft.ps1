
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

function Get-InstalledJavaVersion {
    $key = 'HKLM:\SOFTWARE\JavaSoft\Java Development Kit'
    if (Test-Path $key) {
        $version = (Get-ItemProperty -Path $key).CurrentVersion
        return $version
    }
    return $null
}

function Get-LatestMicrosoftOpenJDK {
    $page = Invoke-WebRequest -Uri "https://learn.microsoft.com/en-us/java/openjdk/download" -UseBasicParsing
    $pattern = 'https:\/\/aka\.ms\/[^"]*jdk-(\d+).*?windows-x64\.msi'
    $matches = [regex]::Matches($page.Content, $pattern)
    if ($matches.Count -gt 0) {
        $latest = $matches | Sort-Object { [int]$_.Groups[1].Value } -Descending | Select-Object -First 1
        return $latest.Value
    }
    return $null
}

function Install-Java {
    param (
        [string]$InstallerUrl
    )
    $tempPath = "$env:TEMP\msopenjdk.msi"
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

$current = Get-InstalledJavaVersion
$latestUrl = Get-LatestMicrosoftOpenJDK

if (-not $latestUrl) {
    Write-Error "Could not fetch latest Microsoft JDK URL."
    Log-Update -Status "Failed - No URL" -CurrentVersion $current -UpdatedVersion "N/A"
    exit 1
}

if (Is-JavaRunning) {
    Write-Host "Java is currently running. Please close Java applications before update."
    Log-Update -Status "Skipped - Java in use" -CurrentVersion $current -UpdatedVersion "N/A"
    exit 1
}

if (-not $current -or $latestUrl -notmatch $current) {
    Write-Host "Installing or updating Java..."
    Install-Java -InstallerUrl $latestUrl
    Set-JavaHome
    Remove-OldJDKs
    
$newVersion = Get-InstalledJavaVersion
if (-not $newVersion) {
    $jdkPath = Get-ChildItem "$env:ProgramFiles\Microsoft" -Directory | Where-Object { $_.Name -like "jdk*" } | Sort-Object Name -Descending | Select-Object -First 1
    if ($jdkPath) {
        $newVersion = $jdkPath.Name -replace 'jdk-', ''
    } else {
        $newVersion = "Unknown"
    }
}

    Write-Host "Java updated to $newVersion"
    Log-Update -Status "Updated" -CurrentVersion $current -UpdatedVersion $newVersion
} else {
    Write-Host "Java is up to date: $current"
    Log-Update -Status "Already Up To Date" -CurrentVersion $current -UpdatedVersion $current
}
