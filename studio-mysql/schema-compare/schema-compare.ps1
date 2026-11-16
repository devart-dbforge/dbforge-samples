# MySQL schema compare - dbForge Studio for MySQL command-line automation
#
# Performs MySQL schema compare operations between two databases and reports structural differences.
# Use this script to compare MySQL databases across environments (dev vs prod) or after migrations.
# Detects MySQL schema diff in tables, indexes, views, stored procedures, and triggers.
# Optionally, generates an HTML report for MySQL database comparison documentation.

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
    [string]$LogFile        = "",
    [string]$ReportFile     = "",
    [string]$ReportFormat   = "HTML",
    [string]$SyncScript     = "",
    [Alias("RunSync")]
    $ExecuteSync            = $false
)

$ExecuteSync = "$ExecuteSync" -match '^\$?(true|1)$'

$workDir = "C:\Automation\SchemaCompareMySQL"
if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }
Set-Location $workDir

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

# Build connection strings
$sourceConn = "User Id=$SourceUser;Host=$SourceHost;Port=$SourcePort;Database=$SourceDatabase;Character Set=$Charset"
if ($SourcePassword) { $sourceConn += ";Password=$SourcePassword" }

$targetConn = "User Id=$TargetUser;Host=$TargetHost;Port=$TargetPort;Database=$TargetDatabase;Character Set=$Charset"
if ($TargetPassword) { $targetConn += ";Password=$TargetPassword" }

# Default file paths
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not $LogFile)    { $LogFile    = "$workDir\$SourceDatabase-vs-$TargetDatabase-$timestamp.log" }
if (-not $ReportFile) { $ReportFile = "$workDir\$SourceDatabase-vs-$TargetDatabase-$timestamp.html" }

# Default sync script path when ExecuteSync is requested
if ($ExecuteSync -and -not $SyncScript) { $SyncScript = "$workDir\SchemaCompare.sql" }

# Build command arguments
$cmdArgs = @(
    "/schemacompare",
    "/source", "connection:$sourceConn",
    "/target", "connection:$targetConn",
    "/log:$LogFile"
)

if ($SyncScript) { $cmdArgs += "/sync:$SyncScript" }

if ($ReportFile) {
    $cmdArgs += "/report:$ReportFile"
    $cmdArgs += "/reportformat:$ReportFormat"
}

& $dbForge @cmdArgs

$exitCode = $LASTEXITCODE

switch ($exitCode) {
    0   { Write-Host "Schema comparison completed successfully." }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file corrupted." }
    40  { Write-Host "ERROR: Server connection failed." }
    100 { Write-Host "Database comparison result: source and target schemas are identical." }
    101 { Write-Host "Database comparison result: schemas differ - review the MySQL schema diff in $LogFile" }
    105 { Write-Host "ERROR: Resource unavailable." }
    106 { Write-Host "ERROR: I/O error." }
    107 { Write-Host "ERROR: Failed to create report." }
    108 { Write-Host "ERROR: There are no objects to perform the specified operation." }
    112 { Write-Host "No objects to sync." }
    114 { Write-Host "ERROR: Error reading objects filters file. Object filters are not loaded." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

Write-Host "Log: $LogFile"
if ($ReportFile) { Write-Host "Report: $ReportFile" }

# Execute sync script only if -ExecuteSync is specified AND this run found differences (exit code 0).
# Without the exit code check a stale script from an earlier run could be applied.
if ($ExecuteSync -and $exitCode -eq 0) {
    if (Test-Path $SyncScript) {
        Write-Host "Executing sync script against $TargetDatabase..."
        & $dbForge /execute /connection:"$targetConn" /inputfile:"$SyncScript"
        $execCode = $LASTEXITCODE
        if ($execCode -eq 0) {
            Write-Host "Sync script executed successfully."
        } else {
            Write-Host "ERROR: Sync script execution failed with exit code: $execCode"
            exit $execCode
        }
        Write-Host "Script: $SyncScript"
    } else {
        Write-Host "ERROR: Sync script not found: $SyncScript"
        exit 106
    }
} elseif ($ExecuteSync) {
    Write-Host "Sync not executed: comparison returned exit code $exitCode (a sync script is written only when differences are found, exit code 0)."
}

exit $exitCode
