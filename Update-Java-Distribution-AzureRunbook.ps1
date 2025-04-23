[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId,
    
    [Parameter(Mandatory = $true)]
    [string]$SharedKey,
    
    [Parameter(Mandatory = $false)]
    [string]$LogType = "JavaUpdateLog",
    
    [Parameter(Mandatory = $false)]
    [string]$ComputerName = $env:COMPUTERNAME
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Constants
$ORACLE_JDK_URL = "https://download.oracle.com/java/24/latest/jdk-24_windows-x64_bin.msi"

function Create-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource) {
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId, $encodedHash
    return $authorization
}

function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType) {
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Create-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource

    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization"        = $signature
        "Log-Type"            = $logType
        "x-ms-date"           = $rfc1123date
        "time-generated-field" = "Timestamp"
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode
}

function Write-Log {
    param (
        [string]$Distribution,
        [string]$Status,
        [string]$CurrentVersion,
        [string]$UpdatedVersion
    )
    
    $logEntry = @{
        Timestamp      = [DateTime]::UtcNow.ToString("o")
        Distribution   = $Distribution
        Status        = $Status
        CurrentVersion = $CurrentVersion
        UpdatedVersion = $UpdatedVersion
        ComputerName  = $ComputerName
    }
    
    $jsonEntry = ConvertTo-Json @($logEntry)
    Post-LogAnalyticsData -customerId $WorkspaceId -sharedKey $SharedKey -body $jsonEntry -logType $LogType
}

function Get-JavaDistributions {
    $javaInstalls = @()
    
    # Check Program Files directories
    $programDirs = @(
        "${env:ProgramFiles}\Java",
        "${env:ProgramFiles}\Eclipse Adoptium",
        "${env:ProgramFiles}\Microsoft\jdk-*"
    )
    
    foreach ($dir in $programDirs) {
        if (Test-Path $dir) {
            Get-ChildItem $dir -Directory | ForEach-Object {
                $version = $_.Name -replace '[^0-9.]', ''
                $distribution = switch -Wildcard ($_.FullName) {
                    "*\Java\jdk*" { "Oracle JDK" }
                    "*\Java\jre*" { "Oracle JRE" }
                    "*\Eclipse Adoptium\jdk*" { "OpenJDK" }
                    "*\Eclipse Adoptium\jre*" { "OpenJRE" }
                    "*\Microsoft\jdk*" { "Microsoft JDK" }
                    default { "Unknown" }
                }
                
                $javaInstalls += @{
                    Distribution = $distribution
                    Version = $version
                    Path = $_.FullName
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
        "Oracle JDK" { return $ORACLE_JDK_URL }
        "Oracle JRE" { return $null }
        { $_ -in "OpenJDK", "OpenJRE" } {
            if ($Type -eq "JDK") {
                return "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_x64_windows_hotspot_21.0.6_7.msi"
            } else {
                return "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jre_x64_windows_hotspot_21.0.6_7.msi"
            }
        }
    }
}

function Install-Java {
    param (
        [string]$InstallerUrl,
        [string]$Distribution,
        [string]$Type
    )
    
    $tempPath = "$env:TEMP\java_installer_$($Distribution)_$($Type).msi"
    
    try {
        Write-Output "Downloading $Distribution $Type..."
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $tempPath -UseBasicParsing
        
        Write-Output "Installing $Distribution $Type..."
        $arguments = "/i `"$tempPath`" /quiet /norestart"
        
        if ($Distribution -eq "Oracle JDK") {
            $arguments += " INSTALLDIR=`"$env:ProgramFiles\Java\jdk-24`" /L*V `"$env:TEMP\oracle_jdk_install.log`""
        }
        
        Start-Process "msiexec.exe" -ArgumentList $arguments -Wait
        Write-Output "$Distribution $Type installed successfully"
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

# Main script execution
try {
    Write-Output "Checking installed Java distributions..."
    $installedJava = Get-JavaDistributions
    
    if ($installedJava.Count -eq 0) {
        Write-Output "No Java installations found."
        Write-Log -Distribution "None" -Status "No Installation Found" -CurrentVersion "N/A" -UpdatedVersion "N/A"
        exit 0
    }
    
    Write-Output "Found the following Java installations:"
    foreach ($install in $installedJava) {
        Write-Output "- $($install.Distribution) $($install.Version) at $($install.Path)"
        
        $currentVersion = $install.Version
        $type = if ($install.Distribution -like "*JDK*") { "JDK" } else { "JRE" }
        $latestUrl = Get-LatestJavaUrl -Distribution $install.Distribution -Type $type
        
        switch ($install.Distribution) {
            "Oracle JDK" {
                if ($currentVersion -ne "24") {
                    $success = Install-Java -InstallerUrl $latestUrl -Distribution $install.Distribution -Type "JDK"
                    Write-Log -Distribution $install.Distribution -Status $(if ($success) { "Updated" } else { "Update Failed" }) `
                        -CurrentVersion $currentVersion -UpdatedVersion $(if ($success) { "24" } else { "N/A" })
                } else {
                    Write-Log -Distribution $install.Distribution -Status "Up to Date" -CurrentVersion $currentVersion -UpdatedVersion $currentVersion
                }
            }
            { $_ -in "OpenJDK", "OpenJRE" } {
                if ($currentVersion -ne "21.0.6+7") {
                    $success = Install-Java -InstallerUrl $latestUrl -Distribution $install.Distribution -Type $type
                    Write-Log -Distribution $install.Distribution -Status $(if ($success) { "Updated" } else { "Update Failed" }) `
                        -CurrentVersion $currentVersion -UpdatedVersion $(if ($success) { "21.0.6+7" } else { "N/A" })
                } else {
                    Write-Log -Distribution $install.Distribution -Status "Up to Date" -CurrentVersion $currentVersion -UpdatedVersion $currentVersion
                }
            }
        }
    }
    
    Write-Output "`nVerifying installations after updates..."
    $updatedJava = Get-JavaDistributions
    foreach ($install in $updatedJava) {
        Write-Output "- $($install.Distribution) $($install.Version) at $($install.Path)"
    }
}
catch {
    Write-Error "Script execution failed: $_"
    Write-Log -Distribution "Error" -Status "Script Failed" -CurrentVersion "N/A" -UpdatedVersion "N/A"
    throw $_
}