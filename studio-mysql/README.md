# dbForge Studio for MySQL: PowerShell automation samples

Ready-to-use PowerShell scripts that automate routine MySQL tasks through the command-line interface of [dbForge Studio for MySQL](https://www.devart.com/dbforge/mysql/studio/). Use them to replace manual GUI steps with repeatable jobs: nightly backups, schema migrations, data sync between environments, test data generation, and documentation builds.

Each folder contains a script (`.ps1`), a description with parameters, usage examples, and exit codes (`.md`), and a screenshot.

## Contents

### Backup and restore

| Sample | What it does |
|---|---|
| [backup-database](backup-database/backup-database.md) | Creates a full MySQL database dump from a saved `.backup` project or from command-line parameters. |
| [restore-database](restore-database/restore-database.md) | Restores a MySQL database from a backup or SQL dump file. |

### Schema comparison and deployment

| Sample | What it does |
|---|---|
| [schema-compare](schema-compare/schema-compare.md) | Compares schemas of two MySQL databases. |
| [schema-compare-project](schema-compare-project/schema-compare-project.md) | Runs a schema comparison from a saved `.scomp` project file. |
| [schema-sync](schema-sync/schema-sync.md) | Generates a schema synchronization script. |
| [generate-sync-script](generate-sync-script/generate-sync-script.md) | Compares schemas and generates a synchronization script for review before deployment. |
| [schema-deploy](schema-deploy/schema-deploy.md) | Compares two schemas and applies the changes to the target database in one run. |

### Data comparison and synchronization

| Sample | What it does |
|---|---|
| [data-compare-sync](data-compare-sync/data-compare-sync.md) | Compares and synchronizes data between two MySQL databases. |
| [synchronize-tables](synchronize-tables/synchronize-tables.md) | Synchronizes data in selected tables between databases. |

### Test data generation

| Sample | What it does |
|---|---|
| [data-generator](data-generator/data-generator.md) | Fills a MySQL database with test data based on command-line parameters. |
| [generate-data-project](generate-data-project/generate-data-project.md) | Generates test data from a saved data generator project file. |

### Documentation

| Sample | What it does |
|---|---|
| [generate-documentation](generate-documentation/generate-documentation.md) | Generates MySQL database documentation. |

## Requirements

- [dbForge Studio for MySQL](https://www.devart.com/dbforge/mysql/studio/) installed
- PowerShell 5.1 or later

## How to use

1. Open the folder of the sample you need and read its `.md` file for parameters and examples.
2. Download the `.ps1` script.
3. Run it from PowerShell with the connection parameters for your environment, for example:

   ```powershell
   .\backup-database.ps1 -Server "prod-host" -Database "mydb" -Password "secret"
   ```

4. To automate the job, call the script from Windows Task Scheduler or a CI/CD pipeline step.

Scripts return exit codes, so you can use them as build or deployment gates in Jenkins, GitHub Actions, Azure DevOps, and other CI/CD tools.

## Related resources

- [dbForge Studio for MySQL](https://www.devart.com/dbforge/mysql/studio/)
- [Download a free trial](https://www.devart.com/dbforge/mysql/studio/download.html)
- [dbForge Studio for MySQL documentation](https://docs.devart.com/studio-for-mysql/)

