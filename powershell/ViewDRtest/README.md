# Disaster Recovery Test of Cohesity Views using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These powershell scripts clone replicated Views for a DR test.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory.

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDRtest/viewDRtest-clone.ps1).content | Out-File viewDRtest-clone.ps1; (Get-Content viewDRtest-clone.ps1) | Set-Content viewDRtest-clone.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDRtest/viewDRtest-delete.ps1).content | Out-File viewDRtest-delete.ps1; (Get-Content viewDRtest-delete.ps1) | Set-Content viewDRtest-delete.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Core Components

* [viewDRtest-clone.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDRtest/viewDRtest-clone.ps1): performs failover/failback operations
* [viewDRtest-delete.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDRtest/viewDRtest-delete.ps1): performs failover/failback operations
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Cohesity Setup (Initial State)

Two clusters (ClusterA and ClusterB) should be configured for replication. ClusterA hosts Cohesity Views that are protected using a protection policy that replicates the view backups to ClusterB.

## Clone Views to ClusterB (for DR testing)

Create a text file (e.g. myviews.txt) containing view names to clone (one view name per line).

Use the viewDRtest-clone.ps1 script to bring the views online at ClusterB for testing (views and child shares will be created with the specified suffix):

```powershell
.\viewDRtest-clone.ps1 -vip clusterB `
                       -username admin `
                       -domain local `
                       -viewList .\myviews.txt `
                       -suffix test
                       -sourceCluster clusterA
```

Note: an output file migratedShares.txt is created, that can be used as input for any DFS folder target updates.

## Delete the Cloned Views and Shares (after DR testing is complete)

Use the viewDRtest-delete.ps1 script to delete the cloned views from ClusterB when testing is done.

```powershell
.\viewDRtest-delete.ps1 -vip clusterB `
                        -username admin `
                        -domain local `
                        -viewList .\myviews.txt `
                        -suffix test
```

## Examples using Helios

Below are examples, same as above except we can connect via Helios:

```powershell
.\viewDRtest-clone.ps1 -clusterName clusterB `
                       -username myuser@mydomain.net `
                       -viewList .\myviews.txt `
                       -suffix test
                       -sourceCluster clusterA

.\viewDRtest-delete.ps1 -clusterName clusterB `
                        -username admin `
                        -domain local `
                        -viewList .\myviews.txt `
                        -suffix test
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

## Other Parameters for viewDRtest-clone.ps1

* -viewNames: (optional) one or more view names to process (comma separated)
* -viewList: (optional) text file of view names to process (one per line)
* -suffix: (required) suffix to apply to cloned views
* -sourceClusterName: (required) name of source cluster that contains production views
* -sourceUsername: (optional) username to authenticate to sourceCluster
* -sourceDomain: (optional) domain to authenticate to sourceCluster
* -sourcePassword: (optional) password to authenticate to sourceCluster
* -sourceMfaCode: (optional) MFA code to authenticate to sourceCluster
* -snapshotDate: (optional) use snapshot from before this date (e.g. '2024-05-23 23:30:00')

## Other Parameters for viewDRtest-delete.ps1

* -viewNames: (optional) one or more view names to process (comma separated)
* -viewList: (optional) text file of view names to process (one per line)
* -suffix: (required) suffix to apply to cloned views
* -deleteSnapshots: (optional) delete any snapshots if the view was protected
* -force: (optional) proceeed with deletions without prompting for confirmation

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
