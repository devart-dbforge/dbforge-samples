# MySQL synchronization tool - synchronize tables between databases using the data comparison feature
# Acts as a MySQL data comparison and synchronization tool (dbForge Data Compare for MySQL):
# Performs row-level MySQL data comparison to detect MySQL table diff between databases.
# Outputs a sync script for MySQL data and table synchronization,
# and, optionally, a rollback script by swapping the source and the target.
# Use the script to compare MySQL tables for differences, compare MySQL data in two databases,
# sync MySQL databases, or compare two MySQL databases for differences after migrations.

param(
    [string]$ProjectDir         = "C:\Automation\SynchronizeTablesMySQL",
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
    $ExecuteScript              = $false,
    $GenerateRollback           = $true,
    [string]$RollbackOutputDir  = "$ProjectDir\Rollback"
)

$ExecuteScript    = "$ExecuteScript"    -match '^\$?(true|1)$'
$GenerateRollback = "$GenerateRollback" -match '^\$?(true|1)$'

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

if (-not (Test-Path $ProjectDir)) { New-Item -ItemType Directory -Path $ProjectDir | Out-Null }

$timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile    = "$ProjectDir\$SourceDatabase-vs-$TargetDatabase-$timestamp.log"
$syncFile   = "$ProjectDir\$SourceDatabase-vs-$TargetDatabase-$timestamp.sql"

Write-Host "MySQL synchronization tool: synchronize tables between databases"
Write-Host "  Source: $SourceHost/$SourceDatabase"
Write-Host "  Target: $TargetHost/$TargetDatabase"

# Build connection strings
$sourceConnection = "User Id=$SourceUser;Host=$SourceHost;Port=$SourcePort;Database=$SourceDatabase;Character Set=$Charset"
if ($SourcePassword) { $sourceConnection += ";Password=$SourcePassword" }

$targetConnection = "User Id=$TargetUser;Host=$TargetHost;Port=$TargetPort;Database=$TargetDatabase;Character Set=$Charset"
if ($TargetPassword) { $targetConnection += ";Password=$TargetPassword" }

& $dbForge /datacompare `
    /source connection:"$sourceConnection" `
    /target connection:"$targetConnection" `
    /log:"$logFile" `
    /sync:"$syncFile"

$exitCode = $LASTEXITCODE
switch ($exitCode) {
    0   { Write-Host "Data differences found - sync script ready to apply."; Write-Host "  Log:    $logFile"; Write-Host "  Script: $syncFile" }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file is corrupted." }
    40  { Write-Host "ERROR: Connection to server failed." }
    100 { Write-Host "Tables are identical - no data differences detected."; Write-Host "  Log: $logFile" }
    101 { Write-Host "Data differences found."; Write-Host "  Log:    $logFile" }
    105 { Write-Host "ERROR: Resource unavailable." }
    106 { Write-Host "ERROR: I/O error." }
    107 { Write-Host "ERROR: Report generation failed." }
    108 { Write-Host "ERROR: No objects selected for comparison." }
    112 { Write-Host "No objects available for synchronization." }
    default { Write-Host "Operation finished with exit code: $exitCode"; Write-Host "  Check log: $logFile" }
}

# Generate the rollback script (swap source and target) BEFORE applying the forward sync:
# once the target matches the source the reverse comparison finds no differences, and the
# rollback script would come out empty - exactly when it is needed most.
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

        & $dbForge /datacompare `
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

# Apply the forward sync script only once the rollback script is in place
if ($ExecuteScript -and $exitCode -eq 0) {
    if (-not $rollbackOk) {
        Write-Host "ERROR: Sync not executed - a rollback script was requested but could not be generated."
        exit 106
    }
    if (-not (Test-Path $syncFile)) {
        Write-Host "ERROR: Sync script not found: $syncFile"
        exit 106
    }

    $backupFile = "$ProjectDir\backup-$TargetDatabase-$timestamp.sql"
    Write-Host "Backing up $TargetHost/$TargetDatabase to: $backupFile"
    & $dbForge /backup `
        /connection:"$targetConnection" `
        /outputfile:"$backupFile"
    $backupCode = $LASTEXITCODE
    if ($backupCode -ne 0) {
        Write-Host "ERROR: Target backup failed with exit code: $backupCode. Synchronization script was not executed."
        exit $backupCode
    }

    Write-Host "Executing synchronization script against $TargetHost/$TargetDatabase ..."
    & $dbForge /execute `
        /connection:"$targetConnection" `
        /inputfile:"$syncFile"
    $execCode = $LASTEXITCODE
    if ($execCode -eq 0) {
        Write-Host "Tables synchronized successfully."
    } else {
        Write-Host "ERROR: Synchronization script execution failed with exit code: $execCode"
        exit $execCode
    }
}

exit $exitCode
