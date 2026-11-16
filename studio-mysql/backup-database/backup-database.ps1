# MySQL database backup - dbForge Studio for MySQL command-line automation
#
# Use this script to back up MySQL database as part of your CI/CD pipelines, scheduled
# maintenance jobs, or on-demand pre-deployment snapshots.
# Supports both the ad-hoc MySQL dump database mode and saved .backup project files.
# Acts as a MySQL backup tool with optional timestamped output filenames.

param(
    [string]$Server         = "localhost",
    [string]$Database       = "bicyclestoredev",
    [string]$Port           = "3306",
    [string]$User           = "root",
    [string]$Password       = "",
    [string]$Charset        = "utf8",
    [string]$ProjectFile    = "",
    [string]$BackupFile     = ""
)

$workDir = "C:\Automation\BackupDatabaseMySQL"
if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }
Set-Location $workDir

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

# Build connection string
$connection = "User Id=$User;Host=$Server;Port=$Port;Database=$Database;Character Set=$Charset"
if ($Password) { $connection += ";Password=$Password" }

if ($ProjectFile) {
    # Use saved .backup project file with optional connection override
    if (-not (Test-Path $ProjectFile)) {
        Write-Host "ERROR: Resource unavailable."
        exit 105
    }

    & $dbForge /backup /projectfile:"$ProjectFile" /connection:"$connection"
} else {
    # Ad-hoc backup - create timestamped backup file
    if (-not $BackupFile) {
        $backupDir = "$workDir\backups"
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $BackupFile = "$backupDir\$Database-$timestamp.sql"
    }

    & $dbForge /backup /connection:"$connection" /outputfile:"$BackupFile"
}

$exitCode = $LASTEXITCODE

switch ($exitCode) {
    0   { Write-Host "MySQL database backup completed successfully." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    12  { Write-Host "ERROR: Unsatisfied dependency." }
    20  { Write-Host "ERROR: Trial expired." }
    40  { Write-Host "ERROR: Server connection failed." }
    105 { Write-Host "ERROR: Resource unavailable." }
    default { Write-Host "Operation finished with exit code: $exitCode" }
}

if ($BackupFile -and -not (Test-Path $BackupFile) -and (Test-Path "$BackupFile.sql")) { $BackupFile = "$BackupFile.sql" }
if ($BackupFile -and (Test-Path $BackupFile)) {
    $size = (Get-Item $BackupFile).Length / 1MB
    Write-Host ("Backup: $BackupFile ({0:N2} MB)" -f $size)
}

exit $exitCode
