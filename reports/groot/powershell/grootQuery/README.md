# Export Groot Data using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script uses ODBC to execute a Groot query and exports the output to a CSV file.

## Get the PostGreSQL ODBC Driver

You can download the latest PSQL ODBC Installer here: <https://www.postgresql.org/ftp/odbc/versions/msi/> (I tested using this version: <https://ftp.postgresql.org/pub/odbc/versions/msi/psqlodbc_13_02_0000.zip>). Simply unzip and run the installer.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'grootQuery'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/groot/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* grootQuery.ps1: the main python script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, and also provide your databse query in a text file named, for example, query.sql, then run the main script like so:

```bash
./grootQuery.ps1 -vip mycluster -username myusername -domain mydomain.net
```

The output will be written to a CSV file.

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -sqlFile: (optional) name of text file containing sql query (default is query.sql)
* -outFile: (optional) name of output CSV file to create (default is grootExport.csv)

## Queries

See <https://github.com/cohesity/community-automation-samples/tree/main/reports/groot/queries> for example queries
