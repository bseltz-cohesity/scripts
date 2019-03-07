# Expunge Data Spillage with PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it!  

This powershell script searches for a file, and displays the ProtectionJobs/Objects where the file is stored. You can then select a ProtectionJob/Object and the script will delete all versions of the ProtectionJob/Object where that file exists. The deletion will include the local snapshots plus any remote replicas and archives.

If you run the script without the -delete switch, the script will only display what it would delete. Use the -delete switch to actually perform the deletions.

Deletions will be logged to scriptPath/expungeLog.txt

## Components

* expungeDataSpillage.ps1: the main powershell script
* cohesityCluster.ps1: Cohesity REST API helper module

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

## Download the Script

Run these commands from PowerShell to download the script(s) into your current directory:

```powershell
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/expungeDataSpillage/expungeDataSpillage.ps1).content | Out-File expungeDataSpillage.ps1; (Get-Content expungeDataSpillage.ps1) | Set-Content expungeDataSpillage.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/expungeDataSpillage/cohesityCluster.ps1).content | Out-File cohesityCluster.ps1; (Get-Content cohesityCluster.ps1) | Set-Content cohesityCluster.ps1
```