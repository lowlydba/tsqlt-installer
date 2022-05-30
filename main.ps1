param(
    [Parameter()]
    [string]$SqlInstance,
    [string]$Database,
    [string]$Version,
    [string]$TempDir = $Env:RUNNER_TEMP,
    [string]$User,
    [string]$Password,
    [switch]$Create
)

$DownloadUrl = "http://tsqlt.org/download/tsqlt/?version=$Version"
$zipFile = Join-Path $TempDir "tSQLt.zip"
$zipFolder = Join-Path $TempDir "tSQLt"

$createDatabaseQuery = "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'$Database')
CREATE DATABASE [$Database];"

try {
    Write-Output "Downloading $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipFile -ErrorAction Stop -UseBasicParsing
    Expand-Archive -Path $zipFile -DestinationPath $zipFolder -Force
    $installFile = (Get-ChildItem $zipFolder -Filter "tSQLt.class.sql").FullName
    $setupFile = (Get-ChildItem $zipFolder -Filter "PrepareServer.sql").FullName
    Write-Output "Download complete."
}
catch {
    Write-Error "Unable to download & extract tSQLt from '$DownloadUrl'. Ensure version is valid." -ErrorAction "Stop"
}

if ($IsMacOs) {
    Write-Output "Only Linux and Windows operation systems supported."
}
elseif ($IsLinux) {
    # Docker SQL can be slow to start fully,
    # bake in a cool off period
    Start-Sleep -Seconds 3

    if ($User -and $Password) {
        if ($Create) {
            sqlcmd -S $SqlInstance -d "master" -Q $createDatabaseQuery -U $User -P $Password
        }

        sqlcmd -S $SqlInstance -d $Database -i $setupFile -U $User -P $Password
        sqlcmd -S $SqlInstance -d $Database -i $installFile -U $User -P $Password -r1 -m-1
    }
    else {
        if ($Create) {
            sqlcmd -S $SqlInstance -d "master" -Q $createDatabaseQuery
        }

        sqlcmd -S $SqlInstance -d $Database -i $setupFile
        sqlcmd -S $SqlInstance -d $Database -i $installFile -r1 -m-1
    }
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

    if ($Create) {
        Invoke-SqlCmd @connSplat -Database "master" -Query $createDatabaseQuery -OutputSqlErrors $true
    }
    elseif (!(Get-SqlDatabase @connSplat -Name $Database)) {
        Write-Error "Database '$Database' not found." -ErrorAction "Stop"
    }

    Invoke-SqlCmd @connSplat -Database $Database -InputFile $setupFile -OutputSqlErrors $true
    Invoke-SqlCmd @connSplat -Database $Database -InputFile $installFile -Verbose -OutputSqlErrors $true
}
