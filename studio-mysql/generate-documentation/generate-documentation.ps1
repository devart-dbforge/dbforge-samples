# MySQL Documenter - MySQL database documentation generator that uses dbForge Studio for MySQL
# Acts as a MySQL database documentation tool and MySQL report builder that generates
# complete documentation in the HTML, PDF, or Markdown format for a target database: tables, views, stored procedures,
# triggers, and relationships - with breadcrumbs, logo, copyright, and title.
# Use the script as a MySQL database reporting tool to document databases automatically
# in audit, onboarding, release, or documentation workflows.

param(
    [string]$Server         = "localhost",
    [string]$Database       = "sakila_dev",
    [string]$Port           = "3306",
    [string]$User           = "root",
    [string]$Password       = "",
    [string]$Charset        = "utf8",
    [string]$OutputName     = "sakila_dev",
    [string]$OutputPath     = "C:\Automation\GenerateDocumentationMySQL",
    [string]$DocumentFormat = "HTML",
    [string]$DocTitle       = "sakila_dev",
    [string]$DocLogo        = "logo.svg",
    [string]$Copyright      = "Copyright $([char]0xA9) All Rights Reserved",
    [string]$Created        = "dd/MM/yyyy",
    [string]$Breadcrumbs    = "Y"
)

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

# Build connection string (database is passed separately via /database)
$connection = "User Id=$User;Host=$Server;Port=$Port;Character Set=$Charset"
if ($Password) { $connection += ";Password=$Password" }

Write-Host "Starting MySQL Documenter: creating documentation for $Server/$Database"

& $dbForge /document `
    /connection:"$connection" `
    /database:"$Database" `
    /documentformat:"$DocumentFormat" `
    /path:"$OutputPath" `
    /output:"$OutputName" `
    /copyright:"$Copyright" `
    /created:"$Created" `
    /doctitle:"$DocTitle" `
    /doclogo:"$DocLogo" `
    /breadcrumbs:"$Breadcrumbs"

$exitCode = $LASTEXITCODE
switch ($exitCode) {
    0   { Write-Host "SUCCESS: Documentation generated successfully. Output: $OutputPath\$OutputName" }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    12  { Write-Host "ERROR: Unsatisfied dependency." }
    15  { Write-Host "ERROR: The value supplied for an argument is invalid." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file corrupted." }
    40  { Write-Host "ERROR: Server connection failed." }
    105 { Write-Host "ERROR: Resource unavailable." }
    108 { Write-Host "ERROR: There are no objects to perform the specified operation." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

exit $exitCode
