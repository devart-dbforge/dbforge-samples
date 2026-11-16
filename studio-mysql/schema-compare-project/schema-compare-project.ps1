# MySQL schema comparison from a project file - dbForge Studio for MySQL automation
#
# Runs MySQL schema comparison using a saved .scomp project with all settings pre-configured.
# Recommended as a MySQL diff tool for repeatable workflows in CI/CD pipelines.
# All MySQL compare database structure settings, filters, and object mappings are
# stored in the project file with no need to pass connection details via the command line.

param(
    [string]$ProjectFile       = "sakila_dev vs. sakila_prod (localhost).scomp",
    [string]$SyncScript        = "sakila_devvs.sakila_prod(localhost).sql",
    [string]$LogFile           = "",
    [string]$ReportFile        = "schema-compare-report.html",
    [string]$ReportFormat      = "HTML",
    [string]$IncludeObjects    = "Filtered",
    [string]$ScriptDiffsStyle  = "removeadd",
    [switch]$Force,
    [Alias("RunSync")]
    $ExecuteSync               = $false,
    [string]$ExecuteConnection = "User Id=root;Host=localhost;Character Set=utf8",
    [string]$SourcePassword    = "",
    [string]$TargetPassword    = ""
)

$ExecuteSync = "$ExecuteSync" -match '^\$?(true|1)$'

$workDir = "C:\Automation\SchemaCompareProjectMySQL"
if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }
Set-Location $workDir

if (-not [System.IO.Path]::IsPathRooted($ProjectFile)) { $ProjectFile = "$workDir\$ProjectFile" }
if ($SyncScript  -and -not [System.IO.Path]::IsPathRooted($SyncScript))  { $SyncScript  = "$workDir\$SyncScript"  }
if ($ReportFile  -and -not [System.IO.Path]::IsPathRooted($ReportFile))  { $ReportFile  = "$workDir\$ReportFile"  }

$dbForgePaths = @(
    "C:\Program Files\Devart\dbForge Studio for MySQL\dbforgemysql.com",
    "C:\Program Files\Devart\dbForge Edge\dbForge Studio for MySQL\dbforgemysql.com"
)
$dbForge = $dbForgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dbForge) { Write-Host "ERROR: dbForge Studio for MySQL not found."; exit 1 }

# Validate project file
if (-not (Test-Path $ProjectFile)) {
    Write-Host "ERROR: Project file not found: $ProjectFile"
    exit 105
}

# Default log file path
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not $LogFile) { $LogFile = "$workDir\schema-compare-project-$timestamp.log" }

# Build command arguments
$cmdArgs = @(
    "/schemacompare",
    "/compfile:$ProjectFile",
    "/log:$LogFile"
)

if ($SourcePassword -or $TargetPassword) {
    [xml]$project = Get-Content -LiteralPath $ProjectFile -Raw -Encoding UTF8
    foreach ($side in "Source", "Target") {
        $node     = $project.CompareDocument.$side
        $conn     = ($node.ConnectionModel.PropertyValue | Where-Object { $_.Name -eq "ConnectionString" }).InnerText
        $password = if ($side -eq "Source") { $SourcePassword } else { $TargetPassword }
        if ($conn -notmatch "(^|;)\s*Database\s*=" -and $node.Schema) { $conn += ";Database=$($node.Schema)" }
        if ($password) { $conn += ";Password=$password" }
        $cmdArgs += "/$($side.ToLower())"
        $cmdArgs += "connection:$conn"
    }
}

if ($TargetPassword -and $ExecuteConnection -and $ExecuteConnection -notmatch "(^|;)\s*Password\s*=") {
    $ExecuteConnection += ";Password=$TargetPassword"
}

# Force = sync directly to DB; otherwise generate SQL script only
if ($Force) {
    $cmdArgs += "/sync"
} else {
    $cmdArgs += "/sync:$SyncScript"
}

if ($IncludeObjects) {
    $cmdArgs += "/IncludeObjects:$IncludeObjects"
}

if ($ScriptDiffsStyle) {
    $cmdArgs += "/ScriptDiffsStyle:$ScriptDiffsStyle"
}

if ($ReportFile) {
    $cmdArgs += "/report:$ReportFile"
    $cmdArgs += "/reportformat:$ReportFormat"
}

& $dbForge @cmdArgs

$exitCode = $LASTEXITCODE

switch ($exitCode) {
    0   { if ($Force) { Write-Host "Schema synchronization completed successfully." } else { Write-Host "Schema differences found - sync script generated successfully." } }
    2   { Write-Host "ERROR: Ctrl+Break." }
    10  { Write-Host "ERROR: Command line usage error." }
    11  { Write-Host "ERROR: Illegal argument duplication." }
    20  { Write-Host "ERROR: Trial expired." }
    30  { Write-Host "ERROR: Project file corrupted: $ProjectFile" }
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
if (-not $Force -and $SyncScript -and (Test-Path $SyncScript)) { Write-Host "Script: $SyncScript" }
if ($ReportFile -and (Test-Path $ReportFile)) { Write-Host "Report: $ReportFile" }

# Execute sync script only if -ExecuteSync is specified AND this run generated one from
# a comparison that found differences (exit code 0). -Force syncs directly and writes no script,
# so without these checks a stale script from an earlier run could be applied.
if ($ExecuteSync -and $SyncScript -and -not $Force -and $exitCode -eq 0) {
    if (Test-Path $SyncScript) {
        if (-not $ExecuteConnection) {
            Write-Host "ERROR: -ExecuteSync requires -ExecuteConnection (e.g. 'User Id=root;Host=localhost;Character Set=utf8')."
        } else {
            Write-Host "Executing sync script..."
            & $dbForge /execute /connection:"$ExecuteConnection" /inputfile:"$SyncScript"
            $syncExitCode = $LASTEXITCODE
            if ($syncExitCode -eq 0) {
                Write-Host "Sync script executed successfully."
            } else {
                Write-Host "ERROR: Sync script execution failed with exit code: $syncExitCode"
                exit $syncExitCode
            }
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


