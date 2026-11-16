# MySQL Schema Compare - compare two databases and generate a synchronization and rollback script.
# Acts as a MySQL diff tool and MySQL schema compare tool: performs MySQL schema comparison
# (MySQL schema diff) and detects MySQL database differences between the source and the target.
# Outputs a sync script for MySQL database synchronization
# and, optionally, a rollback script by swapping the source and the target.
# Use the script to compare MySQL databases, compare MySQL schemas, compare MySQL database structures,
# or compare two MySQL databases for differences before deployments.

param(
    [string]$SourceHost         = "localhost",
    [string]$SourceDatabase     = "sakila_dev",
    [string]$SourcePort         = "3306",
    [string]$SourceUser         = "root",
    [string]$SourcePassword     = "",
    [string]$TargetHost         = "localhost",
    [string]$TargetDatabase     = "sakila_prod",
    [string]$TargetPort         = "3306",
    [string]$TargetUser         = "root",
    [string]$TargetPassword     = "",
    [string]$Charset            = "utf8",
    $ExecuteSync                = $false,
    $GenerateRollback           = $true,
    [string]$RollbackOutputDir  = "C:\Automation\GenerateSyncScriptMySQL\Rollback"
)

$ExecuteSync      = "$ExecuteSync"      -match '^\$?(true|1)$'
$GenerateRollback = "$GenerateRollback" -match '^\$?(true|1)$'

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

$workDir = "C:\Automation\GenerateSyncScriptMySQL"
if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile  = "$workDir\$SourceDatabase-vs-$TargetDatabase-$timestamp.log"
$syncFile = "$workDir\$SourceDatabase-vs-$TargetDatabase-$timestamp.sql"

Write-Host "Running mysql schema compare: $SourceHost/$SourceDatabase vs $TargetHost/$TargetDatabase"
Write-Host "Sync script (database synchronization output): $syncFile"

# Build connection strings for mysql schema compare
$sourceConnection = "User Id=$SourceUser;Host=$SourceHost;Port=$SourcePort;Database=$SourceDatabase;Character Set=$Charset"
if ($SourcePassword) { $sourceConnection += ";Password=$SourcePassword" }

$targetConnection = "User Id=$TargetUser;Host=$TargetHost;Port=$TargetPort;Database=$TargetDatabase;Character Set=$Charset"
if ($TargetPassword) { $targetConnection += ";Password=$TargetPassword" }

& $dbForge /schemacompare `
    /source connection:"$sourceConnection" `
    /target connection:"$targetConnection" `
    /log:"$logFile" `
    /sync:"$syncFile"

$exitCode = $LASTEXITCODE
switch ($exitCode) {
    0   { Write-Host "Schema differences found - sync script generated successfully."; Write-Host "  Log:    $logFile"; Write-Host "  Script: $syncFile" }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file corrupted." }
    40  { Write-Host "ERROR: Server connection failed." }
    100 { Write-Host "MySQL compare result: databases are identical - no database schema changes detected." }
    101 { Write-Host "MySQL compare result: schemas differ - review $logFile" }
    105 { Write-Host "ERROR: Resource unavailable." }
    106 { Write-Host "ERROR: I/O error." }
    107 { Write-Host "ERROR: Failed to create report." }
    108 { Write-Host "ERROR: There are no objects to perform the specified operation." }
    112 { Write-Host "No objects to sync." }
    114 { Write-Host "ERROR: Error reading objects filters file. Object filters are not loaded." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

# Generate the rollback script (swap source and target) BEFORE the sync is applied:
# once the target has been synchronized it matches the source, the reverse comparison
# finds no differences, and the rollback script would come out empty.
$rollbackOk = -not $GenerateRollback
if ($GenerateRollback -and ($exitCode -eq 0 -or $exitCode -eq 101)) {
    Write-Host "Generating rollback script: $TargetHost/$TargetDatabase vs $SourceHost/$SourceDatabase"
    if (-not (Test-Path $RollbackOutputDir)) {
        try {
            New-Item -ItemType Directory -Path $RollbackOutputDir -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "ERROR: Cannot create rollback directory ${RollbackOutputDir}: $_"
        }
    }

    if (Test-Path $RollbackOutputDir) {
        # Timestamped names so an earlier rollback script is never overwritten
        $rollbackLog  = Join-Path $RollbackOutputDir "rollback-$timestamp.log"
        $rollbackFile = Join-Path $RollbackOutputDir "rollback-$timestamp.sql"

        # Same connections as the main compare, with the roles swapped
        & $dbForge /schemacompare `
            /source connection:"$targetConnection" `
            /target connection:"$sourceConnection" `
            /log:"$rollbackLog" `
            /sync:"$rollbackFile"

        $rollbackCode = $LASTEXITCODE
        if ($rollbackCode -eq 100 -or $rollbackCode -eq 112) {
            Write-Host "Rollback script not needed: nothing to revert."
            $rollbackOk = $true
        } elseif (($rollbackCode -eq 0 -or $rollbackCode -eq 101) -and (Test-Path $rollbackFile)) {
            Write-Host "Rollback script saved to: $rollbackFile"
            Write-Host "Rollback log saved to:    $rollbackLog"
            $rollbackOk = $true
        } else {
            Write-Host "WARNING: Rollback script generation finished with exit code: $rollbackCode"
        }
    }
}

# Apply the sync script only once the rollback script is in place
if ($ExecuteSync -and $exitCode -eq 0) {
    if (-not $rollbackOk) {
        Write-Host "ERROR: Sync not executed - a rollback script was requested but could not be generated."
        exit 106
    } elseif (Test-Path $syncFile) {
        Write-Host "Executing sync script against $TargetHost/$TargetDatabase ..."
        & $dbForge /execute `
            /connection:"$targetConnection" `
            /inputfile:"$syncFile"
        $execCode = $LASTEXITCODE
        if ($execCode -eq 0) {
            Write-Host "Sync script executed successfully."
        } else {
            Write-Host "ERROR: Sync script execution failed with exit code: $execCode"
            exit $execCode
        }
    } else {
        Write-Host "ERROR: Sync script not found: $syncFile"
        exit 106
    }
}

exit $exitCode
