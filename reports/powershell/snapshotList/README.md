# List Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script displays a list of existing snapshots.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'snapshotList'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [snapshotList.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/snapshotList/snapshotList.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the main script like so:

```powershell
./snapshotList.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net
```

```text
Connected!
File-Based Backup
    09/08/2019 00:40:01
    09/07/2019 00:40:00
    09/06/2019 11:25:48
Generic NAS
    09/08/2019 01:00:01
    09/07/2019 01:00:01
    09/06/2019 01:00:01
    09/05/2019 01:00:01
    09/04/2019 01:00:01
Infrastructure
    09/07/2019 23:40:00
    09/06/2019 23:40:01
    09/05/2019 23:40:00
    09/04/2019 23:40:00
    09/03/2019 23:40:00
Isilon Backup
    08/16/2019 15:54:09
```

You can include the -sorted parameter to get a list of snapshots sorted by date:

```powershell
./snapshotList.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -sorted
```

```text
Connected!
09/04/2019 23:40:00 (Infrastructure)
09/04/2019 22:40:00 (RMAN Backup)
09/04/2019 08:58:00 (Utils Backup)
09/04/2019 01:40:00 (Scripts Backup)
09/04/2019 01:00:01 (Generic NAS)
09/04/2019 00:20:01 (SQL Backup)
09/04/2019 00:00:00 (Oracle Adapter)
09/03/2019 23:40:00 (Infrastructure)
09/03/2019 22:40:00 (RMAN Backup)
09/03/2019 08:58:00 (Utils Backup)
08/16/2019 15:54:09 (Isilon Backup)
```

If you want to limit the scope to snapshots that are older than say, 30 days, use the -olderThan parameter, like:

```powershell
./snapshotList.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -sorted `
                    -olderThan 30
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -olderThan: (optional) defaults to 0 days old
* -sorted: (optional) sort by date (default is to sort by job name)
