# Disaster Recovery of Cohesity Views using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6 or later

## PowerShell Version Requirements

These scripts must be run on PowerShell 5.1 (Desktop Edition) or higher. The cname and DFS scripts will *NOT* work on PowerShell core. The cname and DFS failover scripts will only run on a Windows Server (201R2 or higher) with the remote server administration tools and PowerShell modules installed for Active Directory, DNS and DFS.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory.

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/viewDR.ps1).content | Out-File viewDR.ps1; (Get-Content viewDR.ps1) | Set-Content viewDR.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/cnameFailover.ps1).content | Out-File cnameFailover.ps1; (Get-Content cnameFailover.ps1) | Set-Content cnameFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/dfsFailover.ps1).content | Out-File dfsFailover.ps1; (Get-Content dfsFailover.ps1) | Set-Content dfsFailover.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/cleanupUnmergedViews.ps1).content | Out-File cleanupUnmergedViews.ps1; (Get-Content cleanupUnmergedViews.ps1) | Set-Content cleanupUnmergedViews.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/cleanupJobs.ps1).content | Out-File cleanupJobs.ps1; (Get-Content cleanupJobs.ps1) | Set-Content cleanupJobs.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/failoverMonitor.ps1).content | Out-File failoverMonitor.ps1; (Get-Content failoverMonitor.ps1) | Set-Content failoverMonitor.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/replicateViews.ps1).content | Out-File replicateViews.ps1; (Get-Content replicateViews.ps1) | Set-Content replicateViews.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Core Components

* [viewDR.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/viewDR.ps1): performs failover/failback operations
* [failoverMonitor.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/failoverMonitor.ps1): displays the status of failover tasks
* [replicateViews.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/replicateViews.ps1): initiates backup/replication of views
* [cleanupJobs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/cleanupJobs.ps1): assigns replication policy and cleans up old objects
* [cleanupUnmergedViews.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/cleanupUnmergedViews.ps1): delete unmerged views
* [cnameFailover.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/cnameFailover.ps1): failover cname and SPN records
* [dfsFailover.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR/dfsFailover.ps1): failover DFS folder targets
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Cohesity Setup (Initial State)

Two clusters (ClusterA and ClusterB) should be configured for replication. ClusterA hosts Cohesity Views that are protected using a protection policy that replicates the view backups to ClusterB.

The protection jobs should be configured to create a Remote View (with the same view name) on the replication target. This remote view will be read-only at ClusterB during normal operations and will become read-write during failover.

## Examples

```powershell
# unplanned failover from clusterA to clusterB
.\viewDR.ps1 -vip clusterB `
             -username admin `
             -domain local `
             -viewList .\myviews.txt `
             -unplannedFailover

# planned failover (start) from clusterA to clusterB
.\viewDR.ps1 -vip clusterB `
             -username admin `
             -domain local `
             -viewList .\myviews.txt `
             -prepareForFailover

# planned failover (finalize) from clusterA to clusterB
.\viewDR.ps1 -vip clusterB `
             -username admin `
             -domain local `
             -viewList .\myviews.txt `
             -plannedFailover

# monitor failovers from clusterA to clusterB
.\failoverMonitor.ps1 -vip clusterB `
                      -username admin `
                      -domain local `
                      -viewList .\myviews.txt

# failover DNS cname from clusterA to clusterB
.\cnameFailover.ps1 -cname mynas `
                    -oldHost clusterA `
                    -newHost clusterB `
                    -domain mydomain.net

# failover DFS namespace from clusterA to clusterB
.\dfsFailover.ps1 -nameSpace "\\mydomain.net\shares" `
                  -shareList .\migratedShares.txt `
                  -disableTarget "\\clusterA" `
                  -enableTarget "\\clusterB"

# initiate post-failover replication
./replicateViews.ps1 -vip clusterB `
                     -username admin `
                     -viewList ./myviews.txt

# after post-failover replication has been completed you can clean up the jobs

# cleanup jobs on the now live clusterB
./cleanupJobs.ps1 -vip clusterB `
                  -username admin `
                  -domain local `
                  -viewList ./myviews.txt `
                  -liveCluster

# cleanup jobs on the old source cluster
./cleanupJobs.ps1 -vip clusterA `
                  -username admin `
                  -domain local `
                  -viewList ./myviews.txt

# you can also cleanup unmerged views from the old source cluster (if unplanned failover was used)
./cleanupUnmergedViews.ps1 -vip clusterA `
                           -username admin `
                           -domain local
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Authenticating to Helios

The Test/Wrapper scripts can be configured to log onto clusters directly, or log onto Helios.

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
