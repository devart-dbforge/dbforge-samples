# MySQL Data Generator - generate test MySQL data using dbForge Studio for MySQL
# Runs a .dgen project to generate random MySQL data for development, QA, and staging environments.
# Acts as a MySQL random data generator: supports multiple project
# files at runtime to populate a MySQL test database,
# build a MySQL sample database, a MySQL demo database, or a MySQL practice database.
# Automates MySQL test data generation as part of environment setup in CI/CD pipelines.

param(
    [string]$Server         = "localhost",
    [string]$Database       = "sakila_dev",
    [string]$Port           = "3306",
    [string]$User           = "root",
    [string]$Password       = "",
    [string]$Charset        = "utf8",
    [string]$ProjectFile    = "C:\Automation\GenerateDataProjectMySQL\sakila_dev.dgen"
)

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

# Pre-flight: verify the mysql data generator project file exists before running
if (-not (Test-Path $ProjectFile)) {
    Write-Host "ERROR: Project file not found: $ProjectFile"
    exit 30
}

Write-Host "MySQL generate test data: $Server/$Database"
Write-Host "  Project: $ProjectFile"

# Build connection string
$connection = "User Id=$User;Host=$Server;Port=$Port;Database=$Database;Character Set=$Charset"
if ($Password) { $connection += ";Password=$Password" }

& $dbForge /generatedata `
    /projectfile:"$ProjectFile" `
    /connection:"$connection"

$exitCode = $LASTEXITCODE
switch ($exitCode) {
    0   { Write-Host "Test MySQL data generation completed successfully. Database: $Server/$Database" }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    12  { Write-Host "ERROR: Unsatisfied dependency." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file corrupted: $ProjectFile" }
    40  { Write-Host "ERROR: Server connection failed." }
    103 { Write-Host "ERROR: Script executed with errors." }
    105 { Write-Host "ERROR: Resource unavailable." }
    108 { Write-Host "ERROR: There are no objects to perform the specified operation." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

exit $exitCode
