param(
    [Parameter()]
    [string]$SqlInstance,
    [string]$Database,
    [string]$Version,
    [string]$TempDir = $Env:RUNNER_TEMP,
    [string]$User,
    [string]$Password,
    [switch]$CreateDatabase,
    [switch]$Update
)

# Vars
$zipFile = Join-Path $TempDir "tSQLt.zip"
$zipFolder = Join-Path $TempDir "tSQLt"
$CreateDatabaseDatabaseQuery = "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'$Database')
CREATE DATABASE [$Database];"
$uninstallQuery = "IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[tsqlt].[Uninstall]')) EXEC [tsqlt].[Uninstall];"
$azureSqlQuery = "IF (SERVERPROPERTY('Edition') = 'SQL Azure') SELECT 1"
$azureVersion = "1-0-5873-27393"

# Exit if MacOS
if ($IsMacOs) {
    Write-Output "Only Linux and Windows operation systems supported at this time."
}
else {
    Write-Output "Thanks for using tSQLt-Installer!"
    Write-Output "tSQLt Website: https://tsqlt.org/"
    Write-Output "Action Repository: https://github.com/lowlydba/tsqlt-installer"
    Write-Output "Please ⭐ if you like!"
    Write-Output "======================"
}

# Is the target Azure SQL?
if ($isLinux) {
    if ($User -and $Password) {
        $Env:SQLCMDUSER = $User 
        $Env:SQLCMDPASSWORD = $Password
    }
    $isAzure = sqlcmd -S $SqlInstance -d "master" -Q $azureSqlQuery
}
elseif ($IsWindows) {
    $isAzure = Invoke-SqlCmd @connSplat -Database "master" -Query $azureSqlQuery -OutputSqlErrors $true
}
if ($isAzure) {
    Write-Output "Azure SQL target detected. Setting version to '$azureVersion'."
    $Version = $azureVersion
}

# Download
try {
    $DownloadUrl = "http://tsqlt.org/download/tsqlt/?version=$Version"
    Write-Output "Downloading from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipFile -ErrorAction "Stop" -UseBasicParsing
    Expand-Archive -Path $zipFile -DestinationPath $zipFolder -Force
    $installFile = (Get-ChildItem $zipFolder -Filter "tSQLt.class.sql").FullName
    $setupFile = (Get-ChildItem $zipFolder -Filter "PrepareServer.sql").FullName
    Write-Output "Download complete."
}
catch {
    Write-Error "Unable to download & extract tSQLt: $($_.Exception.Message)" -ErrorAction "Stop"
}

# Install
if ($IsLinux) {
    # Docker SQL can be slow to start fully, bake in a cool off period
    Start-Sleep -Seconds 3

    if ($CreateDatabase -and (-not $isAzure)) {
        sqlcmd -S $SqlInstance -d "master" -Q $CreateDatabaseDatabaseQuery
    }
    if ($Update) {
        sqlcmd -S $SqlInstance -d $Database -Q $uninstallQuery
    }
    sqlcmd -S $SqlInstance -d $Database -i $setupFile
    sqlcmd -S $SqlInstance -d $Database -i $installFile -r1 -m-1
}
elseif ($IsWindows) {
    $connSplat = @{
        ServerInstance = $SqlInstance
    }
    if ($User -and $Password) {
        $SecPass = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $SecPass
        $connSplat.add("Credential", $Credential)
    }

    if ($CreateDatabase) {
        Invoke-SqlCmd @connSplat -Database "master" -Query $CreateDatabaseDatabaseQuery -OutputSqlErrors $true
    }
    if ($Update) {
        Invoke-SqlCmd @connSplat -Database $Database -Query $uninstallQuery -OutputSqlErrors $true
    }
    Invoke-SqlCmd @connSplat -Database $Database -InputFile $setupFile -OutputSqlErrors $true
    Invoke-SqlCmd @connSplat -Database $Database -InputFile $installFile -Verbose -OutputSqlErrors $true
}
