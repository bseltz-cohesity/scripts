# Expunge Data Spillage with PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

This powershell script searches for a file, and displays the ProtectionJobs/Objects where the file is stored. You can then select a ProtectionJob/Object and the script will delete all versions of the ProtectionJob/Object where that file exists. The deletion will include the local snapshots plus any archives. Replicas can deleted by running the script against the replica cluster.

If you run the script without the -delete switch, the script will only display what it would delete. Use the -delete switch to actually perform the deletions.

Deletions will be logged to scriptPath/expungeLog.txt

## Components

* [expungeDataSpillage.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/expungeDataSpillage/expungeDataSpillage.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
### usage: ./expungeDataSpillage.ps1 -vip mycluster -username admin [ -domain local ] -search 'partial/filepath' [ -delete ]
```

First, run the script WITHOUT the -delete switch to see what would be deleted.

```powershell
powershell> ./expungeDataSpillage.ps1 -vip mycluster -username admin [ -domain mydomain ] -search 'secretfile'
Connected!
- Started at 03/31/2019 05:37:18 -------

Searching for secretfile...

Matches were found in the following objects
-------------------------------------------
CentOS3.mydomain.net (in job: CentOS3)
CentOS3.mydomain.net (in job: File-Based Backup)
AWSControlVM (in job: Infrastructure)

Search Results:

1: /home/myuser/scripts/secretfile
   CentOS3::CentOS3.mydomain.net
--
2: /home/myuser/scripts/secretfile
   File-Based Backup::CentOS3.mydomain.net
--
3: /home/myuser/secretfile
   Infrastructure::AWSControlVM
--
0: Select All

Select Files to Expunge:
Enter one or more (comma separated) id(s):
```

Select one or more (comma separated) id(s) from the file list

```powershell
Please select ID to expunge: 0

Processing /home/myuser/scripts/secretfile...

Deleting object CentOS3.mydomain.net from affected runs of job: File-Based Backup
  BSeltzVE01 (03/31/2019 00:40:00)
  S3 (03/31/2019 00:40:00)
  BSeltzVE01 (03/30/2019 17:59:53)
  S3 (03/30/2019 17:59:53)
  CohesityVE (03/31/2019 00:40:00)
  CohesityVE (03/30/2019 17:59:53)

Processing /home/myuser/secretfile...

Deleting object AWSControlVM from affected runs of job: Infrastructure
  no objects left to delete

Summary of Affected Objects Processed
-------------------------------------
(retained) CentOS3:CentOS3.mydomain.net
(processed) File-Based Backup:CentOS3.mydomain.net
(processed) Infrastructure:AWSControlVM

- Ended at 03/31/2019 05:37:25 -------
```

Then, if you're happy with what would be deleted, re-run the script again and include the -delete switch. THIS WILL DELETE BACKUP DATA!!!

Please note that there may be some delay before the deletions are reflected in file search results.

## Download the Script

Run these commands from PowerShell to download the script(s) into your current directory:

```powershell
# download commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/expungeDataSpillage/expungeDataSpillage.ps1).content | Out-File expungeDataSpillage.ps1; (Get-Content expungeDataSpillage.ps1) | Set-Content expungeDataSpillage.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# end download commands
```
