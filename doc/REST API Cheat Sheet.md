# REST API Cheat Sheet

How to enable yourself to demo the Cohesity REST API

## Install PowerShell Core on your Mac 

Download the PowerShell Cofre .pkg file for MacOS here: https://github.com/PowerShell/PowerShell#get-powershell

After installation you can launch powershell from a terminal session with the command:

```bash
  pwsh
```

## Install the Cohesity PowerShell Module

To install the Cohesity PowerShell cmdlets, run the following command from within your new PowerShell session.

Installing for the first time:
```powershell
>  Install-Module -Name Cohesity.PowerShell.Core
```

Upgrading to the latest version:
```powershell
>  Update-Module -Name Cohesity.PowerShell.Core
```

**Note**: On Windows, using full PowerShell (not Core), install the Cohesity.PowerShell module instead of Cohesity.PowerShell.Core

## Connect to a Cohesity Cluster

```powershell
> Connect-CohesityCluster -Server mycluster              

cmdlet Connect-CohesityCluster at command pipeline position 1
Supply values for the following parameters:
Credential
User: admin
Password for user admin: *****

Connected to the Cohesity Cluster mycluster Successfully
```

* expungeDataSpillage.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
### usage: ./expungeDataSpillage.ps1 -vip mycluster -username admin [ -domain local ] -search 'partial/filepath' [ -delete ]
```

First, run the script WITHOUT the -delete switch to see what would be deleted.

```powershell
powershell> ./expungeDataSpillage.ps1 -vip mycluster -username admin [ -domain mydomain ] -search 'jobmonitor.sh'
Connected!
Searching for jobmonitor.sh...
Search Results:
----
0: /home/seltzerb/old-jobMonitor.sh
VM Backup::CentOS1
----
1: /home/seltzerb/jobMonitor.sh
VM Backup::CentOS1
----
Please select ID to expunge: 
```

Select an item from the list by typing the ID (e.g. 0) 

```powershell
Please select ID to expunge: 0
Searching for versions to delete...
Deleting CentOS1 from VM Backup: 01/17/2019 23:30:01
  Local Snapshot
  Archive on S3
Deleting CentOS1 from VM Backup: 01/15/2019 23:30:01
  Local Snapshot
  Archive on S3
Deleting CentOS1 from VM Backup: 01/14/2019 23:30:01
  Local Snapshot
  Archive on S3
Deleting CentOS1 from VM Backup: 01/13/2019 23:30:00
  Archive on S3
Deleting CentOS1 from VM Backup: 01/12/2019 23:30:01
  Archive on S3
Deleting CentOS1 from VM Backup: 01/11/2019 23:30:01
  Archive on S3
Deleting CentOS1 from VM Backup: 01/10/2019 23:30:00
  Archive on S3
Deleting CentOS1 from VM Backup: 01/09/2019 23:30:01
  Archive on S3
```

Then, if you're happy with what would be deleted, re-run the script again and include the -delete switch. THIS WILL DELETE BACKUP DATA!!!

Please note that there may be some delay before the deletions are reflected in file search results. 
