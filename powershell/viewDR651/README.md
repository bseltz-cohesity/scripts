# Disaster Recovery of Cohesity Views using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These powershell scripts recover replicated views at the DR site.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/viewDRcollect.ps1).content | Out-File viewDRcollect.ps1; (Get-Content viewDRcollect.ps1) | Set-Content viewDRcollect.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/viewDRclone.ps1).content | Out-File viewDRclone.ps1; (Get-Content viewDRclone.ps1) | Set-Content viewDRclone.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/viewDRdelete.ps1).content | Out-File viewDRdelete.ps1; (Get-Content viewDRdelete.ps1) | Set-Content viewDRdelete.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/0-collect.ps1).content | Out-File 0-collect.ps1; (Get-Content 0-collect.ps1) | Set-Content 0-collect.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/1-failover.ps1).content | Out-File 1-failover.ps1; (Get-Content 1-failover.ps1) | Set-Content 1-failover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/2-failback.ps1).content | Out-File 2-failback.ps1; (Get-Content 2-failback.ps1) | Set-Content 2-failback.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/3-failoverTest.ps1).content | Out-File 3-failoverTest.ps1; (Get-Content 3-failoverTest.ps1) | Set-Content 3-failoverTest.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/4-endFailoverTest.ps1).content | Out-File 4-endFailoverTest.ps1; (Get-Content 4-endFailoverTest.ps1) | Set-Content 4-endFailoverTest.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/5-perVipFailover.ps1).content | Out-File 5-perVipFailover.ps1; (Get-Content 5-perVipFailover.ps1) | Set-Content 5-perVipFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/cnameFailover.ps1).content | Out-File cnameFailover.ps1; (Get-Content cnameFailover.ps1) | Set-Content cnameFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR651/dfsFailover.ps1).content | Out-File dfsFailover.ps1; (Get-Content dfsFailover.ps1) | Set-Content dfsFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* viewDRcollect.ps1: collect view metatdata at the primary site
* viewDRclone.ps1: clone views at the DR site
* viewDRdelete.ps1: delete views (from primary, or from DR after a DR test or failback)
* cnameFailover.ps1: failover cname and SPN records
* dfsFailover.ps1: failover DFS folder targets
* 0-collect.ps1: wrapper for collection
* 1-failover.ps1: wrapper for failover
* 2-failback.ps1: wrapper for failback
* 3-failoverTest.ps1: wrapper script for quick DR test
* 4-endFailoverTest.ps1: wrapper script to clean up after quick DR test
* 5-perVipFailover.ps1 wrapper script to failover individual VIPs (e.g. for SQL dump views)
* cohesity-api.ps1: the Cohesity REST API helper module

First, create a location to store view metadata that will be reachable from both the primary and DR sites. It is strongly recommended that this location be at the DR site so that it will be available at time of recovery. This could be a view on the DR cluster (e.g. \\\\myDRcluster\viewDR)

Then, run the viewDRcollect.ps1 script to collect the metadata of the views at the primary site. This script can be scheduled to run periodically (daily).

```powershell
.\viewDRcollect.ps1 -vip mycluster -username admin [ -domain local ] -outPath \\myDRcluster\viewDR
```

At time of DR, you can recover one view:

```powershell
.\viewDRclone.ps1 -vip myDRcluster -username admin [ -domain local ] -viewName myview -inPath \\myDRcluster\viewDR\mycluster
```

Or you can recover all views:

```powershell
.\viewDRclone.ps1 -vip myDRcluster -username admin [ -domain local ] -inPath \\myDRcluster\viewDR\mycluster -all
```

The clone script outputs a text file list of views that have been cloned. This can be used later by the delete script (using the -viewList parameter) to delete the correct list of views.

After completing a DR test, you can delete all of the test views:

```powershell
.\viewDRdelete.ps1 -vip myDRcluster -username admin [ -domain local ] -inPath \\myDRcluster\viewDR\mycluster -all
```

Depending on your environment, you may be using DFS or DNS cnames to direct your users to file shares. In these cases you can use the DFS and cname scripts like so:

```powershell
# toggle dfs folder targets
.\dfsFailover.ps1 -nameSpace \\mydomain.net\shares -shareList .\migratedShares.txt -disableTarget \\myCluster.mydomain.net -enableTarget \\myDRcluster.mydomain.net
```

```powershell
# toggle cnames and SPNs
.\cnameFailover.ps1 -cname mynas -oldHost mycluster -newHost myDRcluster -domain mydomain.net
```

## Collection Script Parameters

* -vip: Cohesity cluster to connect to (primary side)
* -username: Cohesity username
* -domain: (optional) AC Domain of Cohesity user (defaults to local)
* -useApiKey: (optional) use API Key for authentication
* -password: (optional) will use stored password if omitted
* -outPath: path to deposit view metadata files (recommend this be an SMB path at the DR site)

## Clone Script Parameters

* -vip: Cohesity cluster to connect to (primary side)
* -username: Cohesity username
* -domain: (optional) AC Domain of Cohesity user (defaults to local)
* -useApiKey: (optional) use API Key for authentication
* -password: (optional) will use stored password if omitted
* -viewNames: (optional) comma separated list of view names to clone
* -viewList: (optional) text file containing view list to clone (one view name per line)
* -all: (optional) clone all available views
* -policyName: (optional) protect cloned view with this policy
* -suffix: (optional) add suffix to view names at DR site (good for quick test)
* -inPath: path to output files from the collector script
* -snapshotDate: (optional) choose the latest backup from on or before this date (e.g. '2021-10-20 23:59:00')

## Delete Script Parameters

* -vip: Cohesity cluster to connect to (primary side)
* -username: Cohesity username
* -domain: (optional) AC Domain of Cohesity user (defaults to local)
* -useApiKey: (optional) use API Key for authentication
* -password: (optional) will use stored password if omitted
* -viewNames: (optional) comma separated list of view names to clone
* -viewList: (optional) text file containing view list to clone (one view name per line)
* -all: (optional) clone all available views
* -suffix: (optional) add suffix to views at DR site (good for quick test)
* -inPath: (optional) path to output files from the collector script (only needed when using -all)
* -deleteSnapshots: (optional) delete leftover snapshots when the protection job is deleted

## CNAME Script Parameters

* -cname: alias name
* -oldHost: old address to remove from cname
* -newHost: new address to add to cname
* -domain: DNS zone name

## DFS Script Parameters

* -nameSpace: UNC path of DFS namespace
* -shareList: text file containing shares that have been migrated
* -disableTarget:  UNC path of old target (e.g. \\myCluster.mydomain.net)
* -enableTarget: UNC path of new target (e.g. \\myDRcluster.mydomain.net)

## Scheduling PowerShell Scripts

Please review this PDF for help scheduling PowerShell scripts: <https://github.com/bseltz-cohesity/scripts/blob/master/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>
