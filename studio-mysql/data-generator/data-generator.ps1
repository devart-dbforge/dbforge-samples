# MySQL data generator - dbForge Studio for MySQL command-line automation
#
# Runs a .dgen project to generate MySQL test data for development and QA environments.
# Use this script to create sample database content, populate a MySQL test database,
# or generate a MySQL random dataset that respects referential integrity.
# Automates MySQL random data generation as part of the environment setup in CI/CD pipelines.

param(
    [string]$Server         = "localhost",
    [string]$Database       = "bicyclestoredev",
    [string]$Port           = "3306",
    [string]$User           = "root",
    [string]$Password       = "",
    [string]$Charset        = "utf8",
    [string]$ProjectFile    = "C:\Automation\DataGeneratorMySQL\bicyclestoredev.dgen"
)

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

if (-not (Test-Path $ProjectFile)) {
    Write-Host "ERROR: Project file not found: $ProjectFile"
    exit 30
}

Write-Host "Starting MySQL test data generation for $Server/$Database using project: $ProjectFile"

$connection = "User Id=$User;Host=$Server;Port=$Port;Database=$Database;Character Set=$Charset"
if ($Password) { $connection += ";Password=$Password" }

& $dbForge /generatedata `
    /projectfile:"$ProjectFile" `
    /connection:"$connection"

$exitCode = $LASTEXITCODE

switch ($exitCode) {
    0   { Write-Host "MySQL test data generation completed successfully." }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    12  { Write-Host "ERROR: Unsatisfied dependency." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file not found or corrupted: $ProjectFile" }
    40  { Write-Host "ERROR: Server connection failed." }
    103 { Write-Host "ERROR: Script executed with errors." }
    105 { Write-Host "ERROR: Resource unavailable." }
    108 { Write-Host "ERROR: There are no objects to perform the specified operation." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

exit $exitCode
