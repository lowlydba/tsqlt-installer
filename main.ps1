param(
    [Parameter()]
    [string]$SqlInstance,
    [string]$Database,
    [string]$Version,
    [string]$TempDir = $Env:RUNNER_TEMP,
    [string]$User,
    [string]$Password,
    [switch]$CreateDatabase,
    [bool]$Update = $false
)

# Vars
$zipFile = Join-Path -Path $TempDir -ChildPath "tSQLt.zip"
$zipFolder = Join-Path -Path $TempDir -ChildPath "tSQLt"
$installFileName = "tsqlt.class.sql"
$setupFileNames = @("PrepareServer.sql", "SetClrEnabled.sql") # Setup file varies depending on version - will be one or the other
$createDatabaseDatabaseQuery = "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'$Database') CREATE DATABASE [$Database];"
$uninstallQuery = "IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[tsqlt].[Uninstall]')) EXEC [tsqlt].[Uninstall];"
$azureSqlQuery = "IF (SERVERPROPERTY('Edition') = 'SQL Azure') SELECT 1"
$azureVersion = "1-0-5873-27393"

# Exit if MacOS
if ($IsMacOs) {
    Write-Error -Message "Only Linux and Windows supported at this time."
}

# Is the target Azure SQL?
if ($isLinux) {
    # Docker SQL can be slow to start fully, bake in a cool off period
    Start-Sleep -Seconds 3

    if ($User -and $Password) {
        $Env:SQLCMDUSER = $User
        $Env:SQLCMDPASSWORD = $Password
    }
    $isAzure = sqlcmd -S $SqlInstance -d "master" -Q $azureSqlQuery
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

    $isAzure = Invoke-SqlCmd @connSplat -Database "master" -Query $azureSqlQuery -OutputSqlErrors $true
}
if ($isAzure) {
    if ($Version -ne $azureVersion) {
        Write-Output "Azure SQL target detected. Setting version to '$azureVersion'."
        $Version = $azureVersion
    }
    if ($CreateDatabase) {
        Write-Output "Unable to create a database on Azure SQL - assuming target database exists."
        $CreateDatabase = $false
    }
}

# Download
try {
    $DownloadUrl = "http://tsqlt.org/download/tsqlt/?version=$Version"
    Write-Output "Downloading from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipFile -ErrorAction "Stop" -UseBasicParsing
    Write-Output "Download complete."

    Write-Output "Unzipping $zipFile"
    Expand-Archive -Path $zipFile -DestinationPath $zipFolder -Force
    $installFile = (Get-ChildItem -Path $zipFolder -Filter $installFileName).FullName
    $setupFile = (Get-ChildItem -Path $zipFolder | Where-Object Name -in $setupFileNames).FullName

    # Validate files exist
    if (!(Test-Path $installFile)) {
        Write-Error -Message "Unable to find installer file: '$installFileName'."
    }
    if (!(Test-Path $setupFile)) {
        Write-Error -Message "Unable to find either setup file: $setupFileNames"
    }
}
catch {
    Write-Error "Unable to download & extract tSQLt: $($_.Exception.Message)" -ErrorAction "Stop"
}

# Install
if ($IsLinux) {
    if ($CreateDatabase) {
        Write-Output "Creating database [$Database]"
        $sqlcmdOutput = & sqlcmd -S $SqlInstance -d "master" -Q $createDatabaseDatabaseQuery 2>&1
    }
    if ($Update) {
        Write-Output "Uninstalling previous tSQLt"
        $sqlcmdOutput = & sqlcmd -S $SqlInstance -d $Database -Q $uninstallQuery 2>&1
    }
    # Azure doesn't need CLR setup
    if (!$isAzure) {
        $sqlcmdOutput = & sqlcmd -S $SqlInstance -d $Database -i $setupFile 2>&1
    }
    Write-Output "Installing tSQLt"
    $sqlcmdOutput = & sqlcmd -S $SqlInstance -d $Database -i $installFile -r1 -m-1 2>&1 | Where-Object { $_ -notlike "Msg 50000*" }
    foreach ($errorRecord in $sqlcmdOutput) {
        Write-Verbose -Message $errorRecord.Exception.Message -Verbose
    }
}
elseif ($IsWindows) {
    if ($CreateDatabase) {
        Write-Output "Creating [$Database]"
        Invoke-SqlCmd @connSplat -Database "master" -Query $createDatabaseDatabaseQuery -OutputSqlErrors $true
    }
    if ($Update) {
        Write-Output "Uninstalling previous tSQLt"
        Invoke-SqlCmd @connSplat -Database $Database -Query $uninstallQuery -OutputSqlErrors $true
    }
    # Azure doesn't need CLR setup
    if (!$isAzure) {
        Invoke-SqlCmd @connSplat -Database $Database -InputFile $setupFile -OutputSqlErrors $true
    }
    Write-Output "Installing tSQLt"
    Invoke-SqlCmd @connSplat -Database $Database -InputFile $installFile -Verbose -OutputSqlErrors $true
}

Write-Output "Thanks for using tSQLt-Installer! Please ⭐ if you like!"
Write-Output "tSQLt Website: https://tsqlt.org/"
Write-Output "Action Repository: https://github.com/lowlydba/tsqlt-installer"
