# MySQL data compare and sync - dbForge Studio for MySQL command-line automation
#
# Performs MySQL data comparison between two databases and generates a SQL sync script.
# Use this script to detect MySQL data diff between environments after deployments or migrations,
# verify the results of MySQL data comparison between two databases, or automate MySQL data synchronization.
# Supports both ad-hoc connections and saved .dcomp project files for repeatable
# comparisons of two MySQL databases to detect differences.

param(
    [string]$SourceHost     = "localhost",
    [string]$SourceDatabase = "bicyclestoredev",
    [string]$SourcePort     = "3306",
    [string]$SourceUser     = "root",
    [string]$SourcePassword = "",
    [string]$TargetHost     = "localhost",
    [string]$TargetDatabase = "bicyclestoreprod",
    [string]$TargetPort     = "3306",
    [string]$TargetUser     = "root",
    [string]$TargetPassword = "",
    [string]$Charset        = "utf8",
    [string]$CompFile       = "",
    [string]$SyncScript     = "",
    [string]$LogFile        = "",
    [string]$ReportFile     = "",
    [string]$ReportFormat   = "HTML",
    [switch]$Force,
    [Alias("ExecuteSync")]
    $ExecuteScript           = $false,
    [string]$ExecuteHost     = "",
    [string]$ExecuteDatabase = "",
    [string]$ExecutePort     = "",
    [string]$ExecuteUser     = "",
    [string]$ExecutePassword = "",
    [string]$ExecuteCharset  = ""
)

$ExecuteScript = "$ExecuteScript" -match '^\$?(true|1)$'

$workDir = "C:\Automation\DataCompareSyncMySQL"
if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }
Set-Location $workDir

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

# Resolve default paths
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not $LogFile)    { $LogFile    = "$workDir\$SourceDatabase-vs-$TargetDatabase-$timestamp.log" }
if (-not $SyncScript) { $SyncScript = "$workDir\$SourceDatabase-vs-$TargetDatabase-$timestamp.sql" }

# Build command arguments
$cmdArgs = @("/datacompare")

if ($CompFile) {
    # Use saved .dcomp project file
    if (-not (Test-Path $CompFile)) {
        Write-Host "ERROR: Comparison file not found: $CompFile"
        exit 105
    }
    $cmdArgs += "/compfile:$CompFile"
} else {
    # Build connection strings from parameters
    $sourceConn = "User Id=$SourceUser;Host=$SourceHost;Port=$SourcePort;Database=$SourceDatabase;Character Set=$Charset"
    if ($SourcePassword) { $sourceConn += ";Password=$SourcePassword" }

    $targetConn = "User Id=$TargetUser;Host=$TargetHost;Port=$TargetPort;Database=$TargetDatabase;Character Set=$Charset"
    if ($TargetPassword) { $targetConn += ";Password=$TargetPassword" }

    $cmdArgs += "/source"
    $cmdArgs += "connection:$sourceConn"
    $cmdArgs += "/target"
    $cmdArgs += "connection:$targetConn"
}

$cmdArgs += "/log:$LogFile"

# Force = sync directly to DB; otherwise generate SQL script only
if ($Force) {
    $cmdArgs += "/sync"
} else {
    $cmdArgs += "/sync:$SyncScript"
}

# Report output
if ($ReportFile) {
    $cmdArgs += "/report:$ReportFile"
    $cmdArgs += "/reportformat:$ReportFormat"
}

& $dbForge @cmdArgs

$exitCode = $LASTEXITCODE

switch ($exitCode) {
    0   { if ($Force) { Write-Host "Data synchronization completed successfully." } else { Write-Host "Data differences found - sync script generated." } }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file is corrupted." }
    40  { Write-Host "ERROR: Connection to server failed." }
    100 { Write-Host "Source and target data are identical." }
    101 { Write-Host "Data differences found." }
    105 { Write-Host "ERROR: Resource unavailable." }
    106 { Write-Host "ERROR: I/O error." }
    107 { Write-Host "ERROR: Report generation failed." }
    108 { Write-Host "ERROR: No objects selected for comparison." }
    112 { Write-Host "No objects available for synchronization." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

Write-Host "Log: $LogFile"
if (Test-Path $SyncScript) { Write-Host "Script: $SyncScript" }
if ($ReportFile -and (Test-Path $ReportFile)) { Write-Host "Report: $ReportFile" }

# Execute sync script against target database if requested
if ($ExecuteScript -and -not $Force -and $exitCode -eq 0) {
    if (-not (Test-Path $SyncScript)) {
        Write-Host "ERROR: Sync script not found: $SyncScript"
        exit 106
    }

    $execHost     = if ($ExecuteHost)     { $ExecuteHost }     else { $TargetHost }
    $execPort     = if ($ExecutePort)     { $ExecutePort }     else { $TargetPort }
    $execDatabase = if ($ExecuteDatabase) { $ExecuteDatabase } else { $TargetDatabase }
    $execUser     = if ($ExecuteUser)     { $ExecuteUser }     else { $TargetUser }
    $execPassword = if ($ExecutePassword) { $ExecutePassword } else { $TargetPassword }
    $execCharset  = if ($ExecuteCharset)  { $ExecuteCharset }  else { $Charset }

    $execConn = "User Id=$execUser;Host=$execHost;Port=$execPort;Database=$execDatabase;Character Set=$execCharset"
    if ($execPassword) { $execConn += ";Password=$execPassword" }

    $backupFile = "$workDir\backup-$execDatabase-$timestamp.sql"
    Write-Host "Backing up $execHost/$execDatabase to: $backupFile"
    & $dbForge /backup /connection:"$execConn" /outputfile:"$backupFile"
    $backupCode = $LASTEXITCODE
    if ($backupCode -ne 0) {
        Write-Host "ERROR: Target backup failed with exit code: $backupCode. Synchronization script was not executed."
        exit $backupCode
    }

    Write-Host "Executing sync script against $execHost/$execDatabase..."
    & $dbForge /execute /connection:"$execConn" /inputfile:"$SyncScript"

    $execExitCode = $LASTEXITCODE
    if ($execExitCode -eq 0) {
        Write-Host "Sync script executed successfully."
    } else {
        Write-Host "ERROR: Sync script execution failed with exit code: $execExitCode"
        exit $execExitCode
    }
}

exit $exitCode


