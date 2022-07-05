# List Clones using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning: This script can delete data

This powershell script displays a list of existing clones (databases and VMs) and optionally tears them down.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'cloneList'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* cloneList.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together and run the main script like so:

```powershell
./cloneList.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net
```

```text
Connected!
9/7/19 5:26:32 AM - Clone-VMs_Sep_7_2019_5-26am
9/7/19 5:25:59 AM - Clone-SQL2012_MSSQLSERVER_CohesityDB_Sep_7_2019_5-25am
```

If you want to tear down the clones, include the -tearDown parameter like so:

```powershell
./cloneList.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -tearDown
```

```text
Connected!
9/7/19 5:26:32 AM - Clone-VMs_Sep_7_2019_5-26am
    tearing down...
9/7/19 5:25:59 AM - Clone-SQL2012_MSSQLSERVER_CohesityDB_Sep_7_2019_5-25am
    tearing down...
```

If you want to limit the scope to clones that are older than say, 30 days, use the -olderThan parameter, like:

```powershell
./cloneList.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -olderThan 30 `
                    -tearDown
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -olderThan: (optional) defaults to 0 days old
* -tearDown: (optional) script will only display the clone list if omitted
