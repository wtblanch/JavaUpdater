[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential,
    
    [Parameter(Mandatory = $false)]
    [switch]$Remote
)

# Self-elevate the script if required
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Function to get installed Java versions
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

# Function to download and install Java
function Install-Java {
    param (
        [hashtable]$Version,
        [string]$Type = "jdk"
    )
    
    $versionNumber = "21.0.6+7"
    $downloadUrl = if ($Type -eq "jdk") {
        "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_x64_windows_hotspot_21.0.6_7.msi"
    } else {
        "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jre_x64_windows_hotspot_21.0.6_7.msi"
    }
    $installerPath = "$env:TEMP\java_installer.msi"
    
    try {
        Write-Host "Downloading Java $Type $versionNumber..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
        
        Write-Host "Installing Java $Type $versionNumber..."
        $arguments = "/i `"$installerPath`" /qn"
        Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait
        
        Write-Host "Java $Type $versionNumber installed successfully"
    }
    catch {
        Write-Error "Failed to install Java $Type $_"
    }
    finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
    }
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
    
    $latestVersion = @{
        Version = "21.0.6+7"
        Major = 21
        Minor = 0
        Security = 6
    }

    if ($Remote) {
        if (-not $Credential) {
            throw "Credential is required for remote execution"
        }

        $session = New-PSSession -ComputerName $ComputerName -Credential $Credential
        try {
            Invoke-Command -Session $session -ScriptBlock {
                param($Version)
                $installJava = {
                    param($Version, $Type)
                    $versionNumber = "21.0.6+7"
                    $downloadUrl = if ($Type -eq "jdk") {
                        "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_x64_windows_hotspot_21.0.6_7.msi"
                    } else {
                        "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jre_x64_windows_hotspot_21.0.6_7.msi"
                    }
                    $installerPath = "$env:TEMP\java_installer.msi"
                    
                    try {
                        Write-Host "Downloading Java $Type $versionNumber..."
                        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
                        
                        Write-Host "Installing Java $Type $versionNumber..."
                        $arguments = "/i `"$installerPath`" /qn"
                        Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait
                        
                        Write-Host "Java $Type $versionNumber installed successfully"
                    }
                    catch {
                        Write-Error "Failed to install Java $Type $_"
                    }
                    finally {
                        if (Test-Path $installerPath) {
                            Remove-Item $installerPath -Force
                        }
                    }
                }
                
                & $installJava -Version $Version -Type "jdk"
                & $installJava -Version $Version -Type "jre"
            } -ArgumentList $latestVersion
        }
        finally {
            Remove-PSSession -Session $session
        }
    }
    else {
        Install-Java -Version $latestVersion -Type "jdk"
        Install-Java -Version $latestVersion -Type "jre"
    }
    
    # Check and log new Java versions after installation
    Write-Host "`nVerifying new Java installations..."
    $newVersions = Get-InstalledJavaVersions
    if ($newVersions.Count -gt 0) {
        Write-Host "Current Java versions after installation:"
        foreach ($version in $newVersions) {
            Write-Host "- $($version.Type) $($version.Version) at $($version.Path)"
        }
    }
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
} 