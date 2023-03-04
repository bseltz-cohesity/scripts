# Disaster Recovery of Cohesity 6.6 Views using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6.0d_u2 P13 or later.

## PowerShell Version Requirements

These scripts must be run on PowerShell 5.1 (Desktop Edition) or higher. The cname and DFS scripts will *NOT* work on PowerShell core. The cname and DFS failover scripts will only run on a Windows Server (201R2 or higher) with the remote server administration tools and PowerShell modules installed for Active Directory, DNS and DFS.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory.

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/plannedFailoverStart.ps1).content | Out-File plannedFailoverStart.ps1; (Get-Content plannedFailoverStart.ps1) | Set-Content plannedFailoverStart.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/plannedFailoverFinalize.ps1).content | Out-File plannedFailoverFinalize.ps1; (Get-Content plannedFailoverFinalize.ps1) | Set-Content plannedFailoverFinalize.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/plannedFailbackStart.ps1).content | Out-File plannedFailbackStart.ps1; (Get-Content plannedFailbackStart.ps1) | Set-Content plannedFailbackStart.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/plannedFailbackFinalize.ps1).content | Out-File plannedFailbackFinalize.ps1; (Get-Content plannedFailbackFinalize.ps1) | Set-Content plannedFailbackFinalize.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/unplannedFailover.ps1).content | Out-File unplannedFailover.ps1; (Get-Content unplannedFailover.ps1) | Set-Content unplannedFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/unplannedFailback.ps1).content | Out-File unplannedFailback.ps1; (Get-Content unplannedFailback.ps1) | Set-Content unplannedFailback.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/viewDR.ps1).content | Out-File viewDR.ps1; (Get-Content viewDR.ps1) | Set-Content viewDR.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/cnameFailover.ps1).content | Out-File cnameFailover.ps1; (Get-Content cnameFailover.ps1) | Set-Content cnameFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/dfsFailover.ps1).content | Out-File dfsFailover.ps1; (Get-Content dfsFailover.ps1) | Set-Content dfsFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/cleanupUnmergedViews.ps1).content | Out-File cleanupUnmergedViews.ps1; (Get-Content cleanupUnmergedViews.ps1) | Set-Content cleanupUnmergedViews.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/enableReplication.ps1).content | Out-File enableReplication.ps1; (Get-Content enableReplication.ps1) | Set-Content enableReplication.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/prepareForFailover.ps1).content | Out-File prepareForFailover.ps1; (Get-Content prepareForFailover.ps1) | Set-Content prepareForFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/prepareForFailback.ps1).content | Out-File prepareForFailback.ps1; (Get-Content prepareForFailback.ps1) | Set-Content prepareForFailback.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/viewDR66/failoverMonitor.ps1).content | Out-File failoverMonitor.ps1; (Get-Content failoverMonitor.ps1) | Set-Content failoverMonitor.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Core Components

* viewDR.ps1: performs failover/failback operations
* failoverMonitor.ps1: displays the status of failover tasks
* enableReplication.ps1: assigns replication policy and cleans up old objects
* cleanupUnmergedViews.ps1: delete unmerged views
* cnameFailover.ps1: failover cname and SPN records
* dfsFailover.ps1: failover DFS folder targets
* cohesity-api.ps1: the Cohesity REST API helper module

## Example Wrapper Scripts for Failover/Failback Preparation

* prepareForFailover.ps1: assigns replication policy and cleans up old objects
* prepareForFailback.ps1: assigns replication policy and cleans up old objects

## Example Wrapper Scripts for Planned Failover/Failback

* plannedFailoverStart.ps1: initiate rapid replication before planned failover
* plannedFailoverFinalize.ps1: finalize planned failover
* plannedFailbackStart.ps1: initiate rapid replication before planned failback
* plannedFailbackFinalize.ps1: finalize planned failback

## Example Wrapper Scripts for Unplanned Failover/Failback

* unplannedFailover.ps1: initiate unplanned failover
* unplannedFailback.ps1: initiate unplanned failback

## Cohesity Setup (Initial State)

Two clusters (ClusterA and ClusterB) should be configured for replication. ClusterA hosts Cohesity Views that are protected using a protection policy that replicates the view backups to ClusterB.

The protection jobs should be configured to create a Remote View (with the same view name) on the replication target. This remote view will be read-only at ClusterB during normal operations and will become read-write during failover.

The following gflag must be set on the clusters to enable the view DR orchestration feature:

```bash
    bridge_enable_nas_dr_orchestrator: true
```

## Authenticating to Helios

The Test/Wrapper scripts can be configured to log onto clusters directly, or log onto Helios.

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

## Unplanned Failover

An unplanned failover will bring the remote view at ClusterB online immediately. Attempts will be made to make the original view at ClusterA read-only if ClusterA is reachable. Note that the original view at ClusterA may have new/changed files that have not yet replicated to ClusterB, so these changes may be lost but may be retrievable later (see section on unmerged views).

## Unplanned Failover Test/Wrapper Scripts

To prepare for unplanned failover, edit the wrapper scripts: unplannedFailover.ps1 and unplannedFailback.ps1.

Each script has configuration settings at the top of the script

```powershell
# general params
$sourceCluster = 'clustera' # the cluster we are failing away from
$targetCluster = 'clusterb' # ths cluster we are failing over to
$userName = 'myhelios@mydomain.net'
$userDomain = 'local'

# DFS params
$dfsNameSpace = '\\sa.corp.cohesity.com\HA'

# DNS params
$cname = 'nas'
$cnameDomain = 'sa.corp.cohesity.com'
```

Enter the vaules as appropriate for your environment.

The command line options of the viewDR.ps1 command define which views to failover. There are several options:

-viewNames: failover specified views, for example: -viewNames view1, view2, view3
-viewList: failover views listed in a text file, for example: -viewList .\myviews.txt

Depending on if your environment uses DFS, DNS CNAMEs, or both, you can comment out the DFS or CNAME commands.

## Executing Unplanned Failover/Failback

Once configured, you can execute `unplannedFailover.ps1` to failover the views to ClusterB, and execute `unplannedFailback.ps1` to failback the views to ClusterB (although it's more likely that you would want to perform a planned failback).

When the failover occurs, the views at ClusterB are automatically protected with a local only policy (no replication).

To enable replication, use `prepareForFailover.ps1` or `prepareForFailback.ps1`.

Note that failback can not occur until replication back to ClusterA has succeeded at least one time.

## Unmerged Views After Unplanned Failover/Failback

As mentioned above, unplanned failover creates the possibility that unreplicated changes existed in the views at ClusterA. When an unplanned failover occurs, a copy of the original view will appear with 'UNMERGED' in the name. The customer can refer to this view to retrieve any files that were created/changed during the period between that last replication and the failover event.

You can use `cleanupUnmergedViews.ps1` to aid in the deletion of these unmerged views.

## Planned Failover/Failback

Planned Failover/Failback takes a phased approach to ensure that all changes are replicated before failover. This approach takes more time, but is the recommmended approach to ensure zero data loss. There are two phases:

1) The Start phase: during this phase, replication is performed repeatedly in rapid succession to ensure that there is minimal changes to replicate during the final phase.

2) The Finalize phase: during this phase, both the source and target view are set to read-only and a final replication is performed, after which the view at ClusterB is set as read-write. During this phase, no new writes are allowed at either cluster, so it is recommended that you monitor replication during the Start phase to ensure that replication is pretty well caught up, such that the final replication (and duration of write blocking) will be as short as possible.

Again, when the failover occurs, the views at ClusterB are automatically protected with replication back to ClusterA, in preparation for failback.

## Planned Failover/Failback Test/Wrapper Scripts

`plannedFailoverStart.ps1` initiates the Start phase of failover. At the top of the script are configuration parameters that you should set for your environment.

```powershell
# general params
$targetCluster = 'clusterb'
$userName = 'myhelios@mydomain.net'
$userDomain = 'local'
```

When you execute the script, replication from ClusterA to ClusterB begins to run repeatedly. Monitor the replication at ClusterA to see if the replication runs are completing rapidly. Once the replication is "caught up" we can proceed to the Final phase.

You can monitor the status using `failoverMonitor.ps1` like so:

```powershell
.\failoverMonitor -targetCluster clusterb -usernam admin -viewList myviews.txt
```

`plannedFailoverFinalize.ps1` initiates the final replication and failover. Like the unplanned failover scripts, there are configuration parameters to be setup

```powershell
# general params
$sourceCluster = 'clustera'
$targetCluster = 'clusterb'
$userName = 'myhelios@mydomain.net'
$userDomain = 'local'

# DFS params
$dfsNameSpace = '\\sa.corp.cohesity.com\HA'

# DNS params
$cname = 'nas'
$cnameDomain = 'sa.corp.cohesity.com'
```

Set your parameters as appropriate, and comment out the DFS and CNAME commands as appropriate.

When you execute the script, the ciew at ClusterA will be set to read-only and a final replication will occur, then the view at ClusterB will be marked as readwrite.

`plannedFailbackStart.ps1` and `plannedFailbackFinalize.ps1` are the same as `plannedFailoverStart.ps1` and `plannedFailoverFinalize.ps1` but in reverse (the source and target clusters are reversed).

## Monitoring Failover Tasks

You can use the `failoverMonitor.ps1` script to display the status of failover/failback tasks. Run the script against the target cluster that you are failing over/back to, like so:

```powershell
.\failoverMonitor -targetCluster clusterb -usernam admin -viewList myviews.txt
```

## DFS Failover

If the views are hosted behind a DFS namespace, the `dfsFailover.ps1` command can be used to enable the folder targets that point to ClusterB, and disable the folder targets that point to clusterA during failover (and the reverse during failback). For this command to work, the scripts must be run on PowerShell 5.1 Desktop Edition running on a Windows Server 201R2 (or later) that has the DFS management tools installed.

## CNAME Failover

If the views are accessed using a DNS alias (CNAME), the `cnameFailover.ps1` command can be used to update the cname record to point to ClusterB during failover (and the reverse during failback). The script will also migrate the service principal name(s) for the CNAME from the Active Directory computer account for ClusterA to the computer account for ClusterB during failover/failback. For this command to work, the scripts must be run on PowerShell 5.1 Desktop Edition running on a Windows Server 201R2 (or later) that has the Active Directory PowerShell module installed.
