# MySQL schema sync script generator - dbForge Studio for MySQL command-line automation
#
# Compares two MySQL databases and generates a SQL script to synchronize two MySQL databases.
# This is the "generate only" phase of a safe MySQL database synchronization workflow:
# review the MySQL schema diff output before applying any changes.
# Use schema-deploy.ps1 to both generate and execute, or run this script to identify MySQL diff
# between two databases and apply the resulting script through your own change process.

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
    [string]$SyncScript     = "",
    [string]$LogFile        = "",
    [switch]$Force,
    [Alias("RunSync")]
    $ExecuteSync            = $false
)

$ExecuteSync = "$ExecuteSync" -match '^\$?(true|1)$'

$workDir = "C:\Automation\SchemaSyncMySQL"
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

# Resolve default paths
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not $SyncScript) { $SyncScript = "$workDir\$SourceDatabase-vs-$TargetDatabase-schema-sync-$timestamp.sql" }
if (-not $LogFile)    { $LogFile    = "$workDir\$SourceDatabase-vs-$TargetDatabase-schema-sync-$timestamp.log" }

# Build command arguments
$cmdArgs = @(
    "/schemacompare",
    "/source", "connection:$sourceConn",
    "/target", "connection:$targetConn",
    "/log:$LogFile"
)

# Force = sync directly to DB; otherwise generate SQL script only
if ($Force) {
    $cmdArgs += "/sync"
} else {
    $cmdArgs += "/sync:$SyncScript"
}

& $dbForge @cmdArgs

$exitCode = $LASTEXITCODE

switch ($exitCode) {
    0   { if ($Force) { Write-Host "Schema synchronization completed successfully." } else { Write-Host "Schema differences found - sync script generated successfully." } }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file corrupted." }
    40  { Write-Host "ERROR: Server connection failed." }
    100 { Write-Host "MySQL compare result: databases are identical - no database schema changes detected." }
    101 { Write-Host "MySQL compare result: schemas differ - review $LogFile" }
    105 { Write-Host "ERROR: Resource unavailable." }
    106 { Write-Host "ERROR: I/O error." }
    107 { Write-Host "ERROR: Failed to create report." }
    108 { Write-Host "ERROR: There are no objects to perform the specified operation." }
    112 { Write-Host "No objects to sync." }
    114 { Write-Host "ERROR: Error reading objects filters file. Object filters are not loaded." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

Write-Host "Log: $LogFile"
if (-not $Force -and (Test-Path $SyncScript)) { Write-Host "Script: $SyncScript" }

# Execute sync script only if -ExecuteSync is specified AND this run generated one from
# a comparison that found differences (exit code 0). -Force already applied the changes directly,
# so there is no script from this run and a stale one must not be executed.
if ($ExecuteSync -and -not $Force -and $exitCode -eq 0) {
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
    } else {
        Write-Host "ERROR: Sync script not found: $SyncScript"
        exit 106
    }
} elseif ($ExecuteSync -and $Force) {
    Write-Host "Sync not executed separately: -Force already applied the changes directly."
} elseif ($ExecuteSync) {
    Write-Host "Sync not executed: comparison returned exit code $exitCode (a sync script is written only when differences are found, exit code 0)."
}

exit $exitCode


