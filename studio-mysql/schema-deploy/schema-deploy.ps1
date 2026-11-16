# MySQL schema deploy - dbForge Studio for MySQL command-line automation
#
# This script enables two-step MySQL database migration: it performs a MySQL schema comparison to generate
# a SQL sync script, then immediately executes it against the target database.
# Use it to migrate MySQL database changes from dev to staging or prod in one command.
# For a review-before-apply workflow in MySQL (synchronize two databases safely),
# use schema-sync.ps1 to generate the script without executing it.

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
    [switch]$Force
)

$workDir = "C:\Automation\SchemaDeployMySQL"
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
if (-not $SyncScript) { $SyncScript = "$workDir\$SourceDatabase-vs-$TargetDatabase-deploy-$timestamp.sql" }
if (-not $LogFile)    { $LogFile    = "$workDir\$SourceDatabase-vs-$TargetDatabase-deploy-$timestamp.log" }

# Step 1: Compare schemas and generate sync script
Write-Host "Step 1: Comparing schemas and generating sync script..."

$compareArgs = @(
    "/schemacompare",
    "/source", "connection:$sourceConn",
    "/target", "connection:$targetConn",
    "/log:$LogFile"
)

# Force = sync directly to DB; otherwise generate SQL script only
if ($Force) {
    $compareArgs += "/sync"
} else {
    $compareArgs += "/sync:$SyncScript"
}

& $dbForge @compareArgs

$exitCode = $LASTEXITCODE

if ($exitCode -eq 100) {
    Write-Host "Databases are identical. Nothing to deploy."
    Write-Host "Log: $LogFile"
    exit 0
}

if ($exitCode -ne 0 -and $exitCode -ne 101) {
    switch ($exitCode) {
        2   { Write-Host "ERROR: Ctrl+Break." }
        10  { Write-Host "ERROR: Command line usage error." }
        11  { Write-Host "ERROR: Illegal argument duplication." }
        20  { Write-Host "ERROR: Trial expired." }
        30  { Write-Host "ERROR: Project file corrupted." }
        40  { Write-Host "ERROR: Server connection failed." }
        105 { Write-Host "ERROR: Resource unavailable." }
        106 { Write-Host "ERROR: I/O error." }
        107 { Write-Host "ERROR: Failed to create report." }
        108 { Write-Host "ERROR: There are no objects to perform the specified operation." }
        112 { Write-Host "No objects to sync." }
        114 { Write-Host "ERROR: Error reading objects filters file. Object filters are not loaded." }
        default { Write-Host "Schema comparison failed with exit code: $exitCode" }
    }
    Write-Host "Log: $LogFile"
    exit $exitCode
}

# Step 2: Execute the sync script against the target database
if (-not $Force) {
    if (Test-Path $SyncScript) {
        Write-Host "Step 2: Executing sync script against $TargetDatabase..."

        & $dbForge /execute /connection:"$targetConn" /inputfile:"$SyncScript"

        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Host "Deployment completed successfully."
        } else {
            Write-Host "ERROR: Script execution failed with exit code: $exitCode"
        }
    } else {
        Write-Host "WARNING: Sync script was not created. Nothing to execute."
        $exitCode = 112
    }
} else {
    # -Force applies the changes directly during Step 1, so there is no script to execute.
    # Confirm the deployment here, otherwise a -Force run never reports success.
    Write-Host "Step 2: Skipped: -Force applied the changes directly during Step 1."
    Write-Host "Deployment completed successfully."
    # Report the documented success code 0, matching the non-Force path, instead of
    # leaking the comparison code 101 to the caller.
    $exitCode = 0
}

Write-Host "Log: $LogFile"
if (-not $Force -and (Test-Path $SyncScript)) { Write-Host "Script: $SyncScript" }

exit $exitCode


