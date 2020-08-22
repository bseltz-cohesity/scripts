# Disaster Recovery of Cohesity Views using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These powershell scripts recover replicated views at the DR site.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR/viewDRcollect.ps1).content | Out-File viewDRcollect.ps1; (Get-Content viewDRcollect.ps1) | Set-Content viewDRcollect.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR/viewDRclone.ps1).content | Out-File viewDRclone.ps1; (Get-Content viewDRclone.ps1) | Set-Content viewDRclone.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR/viewDRdelete.ps1).content | Out-File viewDRdelete.ps1; (Get-Content viewDRdelete.ps1) | Set-Content viewDRdelete.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* viewDRcollect.ps1: collect view metatdata at the primary site
* viewDRclone.ps1: clone views at the DR site
* viewDRdelete.ps1: delete views (from primary, or from DR after a DR test or failback)
* cohesity-api.ps1: the Cohesity REST API helper module

First, create a location to store view metadata that will be reachable from both the primary and DR sites. It is strongly recommended that this location be at the DR site so that it will be available at time of recovery. This could be a view on the DR cluster (e.g. \\myDRcluster\viewDR)

Then, run the viewDRcollect.ps1 script to collect the metadata of the views at the primary site. This script can be scheduled to run periodically (daily).

```powershell
./viewDRcollect.ps1 -vip mycluster -username admin [ -domain local ] -outPath \\myDRcluster\viewDR
```

At time of DR, you can recover one view:

```powershell
./viewDRclone.ps1 -vip myDRcluster -username admin [ -domain local ] -viewName myview -inPath \\myDRcluster\viewDR\mycluster
```

Or you can recover all views:

```powershell
./viewDRclone.ps1 -vip myDRcluster -username admin [ -domain local ] -inPath \\myDRcluster\viewDR\mycluster -all
```

The clone script outputs a text file list of views that have been cloned. This can be used later by the delete script (using the -viewList parameter) to delete the correct list of views.

After completing a DR test, you can delete all of the test views:

```powershell
./viewDRdelete.ps1 -vip myDRcluster -username admin [ -domain local ] -inPath \\myDRcluster\viewDR\mycluster -all
```

## Collection Script Parameters

* -vip: Cohesity cluster to connect to (primary side)
* -username: Cohesity username
* -domain: (optional) AC Domain of Cohesity user (defaults to local)
* -outPath: path to deposit view metadata files (recommend this be an SMB path at the DR site)

## Clone Script Parameters

* -vip: Cohesity cluster to connect to (primary side)
* -username: Cohesity username
* -domain: (optional) AC Domain of Cohesity user (defaults to local)
* -viewNames: (optional) comma separated list of view names to clone
* -viewList: (optional) text file containing view list to clone (one view name per line)
* -all: (optional) clone all available views
* -policyName: (optional) protect cloned view with this policy
* -inPath: path to output files from the collector script

## Delete Script Parameters

* -vip: Cohesity cluster to connect to (primary side)
* -username: Cohesity username
* -domain: (optional) AC Domain of Cohesity user (defaults to local)
* -viewNames: (optional) comma separated list of view names to clone
* -viewList: (optional) text file containing view list to clone (one view name per line)
* -all: (optional) clone all available views
* -inPath: (optional) path to output files from the collector script (only needed when using -all)
* -deleteSnapshots: (optional) delete leftover snapshots when the protection job is deleted

## Scheduling PowerShell Scripts

Please review this PDF for help scheduling PowerShell scripts: <https://github.com/bseltz-cohesity/scripts/blob/master/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>
