# MySQL database restore - dbForge Studio for MySQL command-line automation
#
# Use this script to restore a MySQL database from a .sql dump or .backup file.
# Supports MySQL database recovery workflows: restoring to a different target database
# name enables cloning environments or verifying MySQL dump restore integrity.
# Typical use: MySQL restore database command-line in CI/CD or disaster recovery.

param(
    [string]$InputFile      = "C:\Automation\RestoreDatabaseMySQL\sakila_202601051132.sql",
    [string]$Server         = "localhost",
    [string]$Database       = "sakila_prod",
    [string]$TargetDatabase = "sakila_dev",
    [string]$Port           = "3306",
    [string]$User           = "root",
    [string]$Password       = "",
    [string]$Charset        = "utf8",
    [string]$Encoding       = "65001"
)

$workDir = "C:\Automation\RestoreDatabaseMySQL"
if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }
Set-Location $workDir

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

# Validate backup file
if (-not (Test-Path $InputFile)) {
    Write-Host "ERROR: Backup file not found: $InputFile"
    exit 105
}

# Build connection string
$connection = "User Id=$User;Host=$Server;Port=$Port;Database=$Database;Character Set=$Charset"
if ($Password) { $connection += ";Password=$Password" }

# Build command arguments
$cmdArgs = @(
    "/restore",
    "/connection:$connection",
    "/inputfile:$InputFile",
    "/encoding:$Encoding"
)

if ($TargetDatabase) {
    $cmdArgs += "/database:$TargetDatabase"
}

& $dbForge @cmdArgs

$exitCode = $LASTEXITCODE

switch ($exitCode) {
    0   { Write-Host "Restore completed successfully." }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    12  { Write-Host "ERROR: Unsatisfied dependency." }
    20  { Write-Host "ERROR: Trial expired." }
    40  { Write-Host "ERROR: Server connection failed." }
    103 { Write-Host "Script executed with errors." }
    105 { Write-Host "ERROR: Resource unavailable." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

exit $exitCode
