# Clone Backup Files to a View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones backup files to a Cohesity view.

Note: Consolidation and Refresh options require PowerShell to have SMB access to the Cohesity view.

## Warning! This script can delete views! Make sure you know what you are doing before you run it

## Download the Scripts

Run these commands from PowerShell to download the scripts into the current folder:

```powershell
# Download Commands
$scriptName = 'cloneBackupToView'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneBackupToView.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/cloneBackupToView/cloneBackupToView.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

To clone all available backups:

```powershell
./cloneBackupToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobName 'My SQL Job' `
                        -objectName mysqlserver.mydomain.net `
                        -viewName cloned
```

To limit access to specific users:

```powershell
./cloneBackupToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobName 'My SQL Job' `
                        -objectName mysqlserver.mydomain.net `
                        -viewName cloned `
                        -access 'mydomain.net\domain admins', mydomain.net\othergroup
```

To list available runs:

```powershell
./cloneBackupToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobName 'My SQL Job' `
                        -listRuns
```

To clone a specific range of run dates:

```powershell
./cloneBackupToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobName 'My SQL Job' `
                        -objectName mysqlserver.mydomain.net `
                        -viewName cloned `
                        -firstRunId 12345 `
                        -lastRunId 12399
```

To delete a view when finished:

```powershell
./cloneBackupToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -viewName cloned `
                        -deleteView
```

To refresh a view (on a schedule):

```powershell
./cloneBackupToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobName 'My SQL Job' `
                        -objectName mysqlserver.mydomain.net `
                        -viewName cloned `
                        -refreshView `
                        -force `
                        -consolidate `
                        -logsOnly
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Basic Parameters

* -jobname: (optional) name of SQL protection job
* -objectName: (optional) name of sqlServer whose backup to clone
* -viewName: (optional) name of new or existing view to clone backup files to
* -waitForRun: (optional) wait for currently run to complete
* -dirPath: (optional) clone a subdirectory (e.g /home/myuser/mydir or /C/users/myuser/mydir)

## Parameters for Run Selection

* -daysToKeep: (optional) clone the past X days (and delete older files from view)
* -listRuns: (optional) list available job run IDs and dates
* -lastRunOnly: (optional) only clone latest run
* -numRuns: (opyional) max number of runs to clone (default is 100)
* -firstRunId: (optional) earliest run to clone (defaults to all)
* -lastRunId: (optional) most recent run to clone (defaultds to all)

## Parameters for View Manipulation

* -access: (optional) Active Directory users/groups (comma separated) to add to share permissions (default is everyone)
* -deleteView: (optional) delete view when finished
* -refreshView: (optional) delete existing files in view
* -force: (optional) do not prompt for confirmation when refreshing or deleting view (DANGEROUS!)

## Whitelist Overrides

* -ips: (optional) cidrs to add, examples: 192.168.1.3/32, 192.168.2.0/24 (comma separated)
* -ipList: (optional) text file of cidrs to add (one per line)
* -readOnly: (optional) readWrite if omitted
* -rootSquash: (optional) enable root squash
* -allSquash: (optional) enable all squash

## Parameters for Folder Manipulation

* -consolidate: (optional) move all files to root of view
* -targetPath: (optional: requires -consolidate) move all files to this directory (e.g. \test\folder)
* -dbFolders: (optional: requires -consolidate) move files into db-named folders
* -logsOnly: (optional: requires -consolidate) only consolidate log files
* -daysToKeep: (optional) clone the past X days (and delete older files from view)
* -objectView: (optional) move files to \hostname\dbname\timestamp folders
