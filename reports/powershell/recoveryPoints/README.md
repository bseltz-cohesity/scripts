# List Recovery Points Per Protected Object

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists available local recovery points for every protected object in Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoveryPoints'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* recoveryPoints.ps1: the main python script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./recoveryPoints.ps1 -vip mycluster -username myusername -domain mydomain.net
```

```text
Connected!

VM Backup (VMware) CentOS2

	             RunDate           SnapExpires        ReplicaExpires        ArchiveExpires
	 3/29/20 11:30:01 PM    4/3/20 11:30:45 PM                     -   4/29/20 11:30:01 PM
	 3/22/20 11:30:00 PM                     -                     -   4/22/20 11:30:00 PM
	 3/15/20 11:00:01 PM                     -                     -   4/15/20 11:00:01 PM
	  3/8/20 11:00:01 PM                     -                     -    4/8/20 11:00:01 PM

NAS Backup (GenericNas) 192.168.1.7:/volume1/backups

	             RunDate           SnapExpires        ReplicaExpires        ArchiveExpires
	  3/30/20 1:20:01 AM     4/4/20 1:20:13 AM     4/4/20 1:22:12 AM                     -
	  3/29/20 1:20:01 AM     4/3/20 1:20:11 AM     4/3/20 1:22:10 AM                     -
	  3/28/20 1:20:00 AM     4/2/20 1:20:10 AM     4/2/20 1:22:12 AM                     -
	  3/27/20 1:20:00 AM     4/1/20 1:20:12 AM     4/1/20 1:22:10 AM                     -
	  3/26/20 1:20:00 AM    3/31/20 1:20:04 AM    3/31/20 1:20:37 AM                     -

Oracle Backup (Oracle) cohesity on oracle.seltzer.net

	             RunDate           SnapExpires        ReplicaExpires        ArchiveExpires
	 3/29/20 11:40:01 PM    4/3/20 11:40:53 PM    4/3/20 11:42:22 PM                     -
	 3/28/20 11:40:00 PM    4/2/20 11:40:52 PM    4/2/20 11:42:21 PM                     -
	 3/27/20 11:40:00 PM    4/1/20 11:40:49 PM    4/1/20 11:42:22 PM                     -
	 3/26/20 11:40:01 PM   3/31/20 11:40:50 PM   3/31/20 11:42:22 PM                     -
	 3/25/20 11:40:01 PM   3/30/20 11:40:49 PM   3/30/20 11:42:22 PM                     -

Report Saved to RecoverPoints-2-14-20_5-05-21_AM.csv
```
