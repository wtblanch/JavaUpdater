[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "JavaUpdateLog.csv"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Add Oracle JDK URL constant
$ORACLE_JDK_URL = "https://download.oracle.com/java/24/latest/jdk-24_windows-x64_bin.msi"

function Get-JavaDistributions {
    $javaInstalls = @()
    
    # Registry paths for different Java distributions
    $paths = @{
        "Oracle JDK" = @(
            "HKLM:\SOFTWARE\JavaSoft\Java Development Kit"
        )
        "Oracle JRE" = @(
            "HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment"
        )
        "OpenJDK" = @(
            "HKLM:\SOFTWARE\JavaSoft\JDK",
            "${env:ProgramFiles}\Eclipse Foundation",
            "${env:ProgramFiles}\Eclipse Adoptium",
            "${env:ProgramFiles}\Microsoft\jdk*"
        )
        "OpenJRE" = @(
            "HKLM:\SOFTWARE\JavaSoft\JRE",
            "${env:ProgramFiles}\Eclipse Foundation",
            "${env:ProgramFiles}\Eclipse Adoptium"
        )
    }

    foreach ($distribution in $paths.Keys) {
        foreach ($path in $paths[$distribution]) {
            if ($path -like "HKLM:*") {
                if (Test-Path $path) {
                    $versions = Get-ChildItem $path -ErrorAction SilentlyContinue
                    foreach ($version in $versions) {
                        $javaHome = (Get-ItemProperty -Path "$($version.PSPath)\$($version.PSChildName)" -ErrorAction SilentlyContinue).JavaHome
                        if ($javaHome -and (Test-Path $javaHome)) {
                            $javaExe = Join-Path $javaHome "bin\java.exe"
                            if (Test-Path $javaExe) {
                                $versionInfo = & $javaExe -version 2>&1
                                $versionString = $versionInfo[0] -replace '.*version "([^"]+)".*', '$1'
                                $vendor = $versionInfo | Where-Object { $_ -match 'Runtime Environment' } | Select-Object -First 1
                                
                                $javaInstalls += @{
                                    Distribution = $distribution
                                    Version = $versionString
                                    Path = $javaHome
                                    Vendor = $vendor
                                }
                            }
                        }
                    }
                }
            } else {
                # Check filesystem paths
                if (Test-Path $path) {
                    $javaHomes = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | 
                                Where-Object { Test-Path (Join-Path $_.FullName "bin\java.exe") }
                    
                    foreach ($javaHome in $javaHomes) {
                        $javaExe = Join-Path $javaHome.FullName "bin\java.exe"
                        $versionInfo = & $javaExe -version 2>&1
                        $versionString = $versionInfo[0] -replace '.*version "([^"]+)".*', '$1'
                        $vendor = $versionInfo | Where-Object { $_ -match 'Runtime Environment' } | Select-Object -First 1
                        
                        $javaInstalls += @{
                            Distribution = $distribution
                            Version = $versionString
                            Path = $javaHome.FullName
                            Vendor = $vendor
                        }
                    }
                }
            }
        }
    }
    
    return $javaInstalls
}

function Get-LatestJavaUrl {
    param (
        [string]$Distribution,
        [string]$Type
    )
    
    switch ($Distribution) {
        "Oracle JDK" {
            return $ORACLE_JDK_URL
        }
        "Oracle JRE" {
            return $null  # Will use jusched.exe instead
        }
        { $_ -in "OpenJDK", "OpenJRE" } {
            if ($Type -eq "JDK") {
                return "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_x64_windows_hotspot_21.0.6_7.msi"
            } else {
                return "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jre_x64_windows_hotspot_21.0.6_7.msi"
            }
        }
    }
}

function Update-OracleJRE {
    param (
        [string]$JavaHome
    )
    
    $juSchedPath = Join-Path $JavaHome "bin\jusched.exe"
    
    if (Test-Path $juSchedPath) {
        try {
            Write-Host "Initiating Oracle JRE update using Java Update Scheduler..."
            Start-Process -FilePath $juSchedPath -ArgumentList "-update" -Wait
            return $true
        }
        catch {
            Write-Warning "Failed to run Java Update Scheduler: $_"
            return $false
        }
    }
    else {
        Write-Warning "Java Update Scheduler not found at: $juSchedPath"
        return $false
    }
}

function Install-Java {
    param (
        [string]$InstallerUrl,
        [string]$Distribution,
        [string]$Type
    )
    
    if ($Distribution -eq "Oracle JRE") {
        return Update-OracleJRE -JavaHome $install.Path
    }
    
    $tempPath = "$env:TEMP\java_installer_$($Distribution)_$($Type).msi"
    
    try {
        Write-Host "Downloading $Distribution $Type..."
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $tempPath -UseBasicParsing
        
        Write-Host "Installing $Distribution $Type..."
        $arguments = "/i `"$tempPath`" /quiet /norestart"
        
        # Add specific arguments for Oracle JDK
        if ($Distribution -eq "Oracle JDK") {
            $arguments += " INSTALLDIR=`"$env:ProgramFiles\Java\jdk-24`" /L*V `"$env:TEMP\oracle_jdk_install.log`""
        }
        
        Start-Process "msiexec.exe" -ArgumentList $arguments -Wait
        Write-Host "$Distribution $Type installed successfully"
        return $true
    }
    catch {
        Write-Error "Failed to install $Distribution $Type $_"
        return $false
    }
    finally {
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force
        }
    }
}

function Log-Update {
    param (
        [string]$Distribution,
        [string]$Status,
        [string]$CurrentVersion,
        [string]$UpdatedVersion
    )
    
    $logLine = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Distribution = $distribution
        Status = $Status
        CurrentVersion = $CurrentVersion
        UpdatedVersion = $UpdatedVersion
        ComputerName = $env:COMPUTERNAME
    }
    
    $logLine | Export-Csv -Path $LogFile -Append -NoTypeInformation -Force
}

# Main script execution
try {
    Write-Host "Checking installed Java distributions..."
    $installedJava = Get-JavaDistributions
    
    if ($installedJava.Count -eq 0) {
        Write-Host "No Java installations found. This script is designed to update existing Java installations only."
        Log-Update -Distribution "None" -Status "No Installation Found" -CurrentVersion "N/A" -UpdatedVersion "N/A"
        exit 0
    }
    
    Write-Host "Found the following Java installations:"
    foreach ($install in $installedJava) {
        Write-Host "- $($install.Distribution) $($install.Version) at $($install.Path)"
        
        $currentVersion = $install.Version
        $type = if ($install.Distribution -like "*JDK*") { "JDK" } else { "JRE" }
        $latestUrl = Get-LatestJavaUrl -Distribution $install.Distribution -Type $type
        
        switch ($install.Distribution) {
            "Oracle JDK" {
                if ($currentVersion -ne "24") {
                    $success = Install-Java -InstallerUrl $latestUrl -Distribution $install.Distribution -Type "JDK"
                    if ($success) {
                        Log-Update -Distribution $install.Distribution -Status "Updated" -CurrentVersion $currentVersion -UpdatedVersion "24"
                    } else {
                        Log-Update -Distribution $install.Distribution -Status "Update Failed" -CurrentVersion $currentVersion -UpdatedVersion "N/A"
                    }
                } else {
                    Log-Update -Distribution $install.Distribution -Status "Up to Date" -CurrentVersion $currentVersion -UpdatedVersion $currentVersion
                }
            }
            "Oracle JRE" {
                $success = Update-OracleJRE -JavaHome $install.Path
                if ($success) {
                    Log-Update -Distribution $install.Distribution -Status "Update Initiated" -CurrentVersion $currentVersion -UpdatedVersion "Latest"
                } else {
                    Log-Update -Distribution $install.Distribution -Status "Update Failed" -CurrentVersion $currentVersion -UpdatedVersion "N/A"
                }
            }
            { $_ -in "OpenJDK", "OpenJRE" } {
                if ($currentVersion -ne "21.0.6+7") {
                    $success = Install-Java -InstallerUrl $latestUrl -Distribution $install.Distribution -Type $type
                    if ($success) {
                        Log-Update -Distribution $install.Distribution -Status "Updated" -CurrentVersion $currentVersion -UpdatedVersion "21.0.6+7"
                    } else {
                        Log-Update -Distribution $install.Distribution -Status "Update Failed" -CurrentVersion $currentVersion -UpdatedVersion "N/A"
                    }
                } else {
                    Log-Update -Distribution $install.Distribution -Status "Up to Date" -CurrentVersion $currentVersion -UpdatedVersion $currentVersion
                }
            }
        }
    }
    
    Write-Host "`nVerifying installations after updates..."
    $updatedJava = Get-JavaDistributions
    foreach ($install in $updatedJava) {
        Write-Host "- $($install.Distribution) $($install.Version) at $($install.Path)"
    }
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}

