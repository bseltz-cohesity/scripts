# Disaster Recovery of Multi-tenant Cohesity Views using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These powershell scripts recover replicated views at the DR site, in a manner that works with Multi-tenancy.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory.

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR-MT/viewDRclone.ps1).content | Out-File viewDRclone.ps1; (Get-Content viewDRclone.ps1) | Set-Content viewDRclone.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR-MT/viewDRcollect.ps1).content | Out-File viewDRcollect.ps1; (Get-Content viewDRcollect.ps1) | Set-Content viewDRcollect.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR-MT/viewDRdelete.ps1).content | Out-File viewDRdelete.ps1; (Get-Content viewDRdelete.ps1) | Set-Content viewDRdelete.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR-MT/cleanupJobs.ps1).content | Out-File cleanupJobs.ps1; (Get-Content cleanupJobs.ps1) | Set-Content cleanupJobs.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Core Components

* [viewDRcollect.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR-MT/viewDRcollect.ps1): performs failover/failback operations
* [viewDRclone.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR-MT/viewDRclone.ps1): performs failover/failback operations
* [viewDRdelete.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR-MT/viewDRdelete.ps1): performs failover/failback operations
* [cleanupJobs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/viewDR-MT/cleanupJobs.ps1): assigns replication policy and cleans up old objects
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Cohesity Setup (Initial State)

Two clusters (ClusterA and ClusterB) should be configured for replication. ClusterA hosts Cohesity Views that are protected using a protection policy that replicates the view backups to ClusterB.

The protection jobs can be configured to create a Remote View with view names that include a "-DR" suffix, e.g. view1-DR, on the replication target. This remote view will be read-only at ClusterB during normal operations.

## Collect and Store View Metadata

Use the cloneDRcollect.ps1 script to collect metadata about the views and store it in a location that will be available at time of DR. The script should be run on a schedule (e.g. daily) so that the metadata is kept up to date.

```powershell
.\viewDRcollect.ps1 -vip clusterA `
                    -username admin `
                    -domain local `
                    -outPath '.'

.\viewDRcollect.ps1 -vip clusterB `
                    -username admin `
                    -domain local `
                    -outPath '.'
```

## Failover Views to ClusterB

Use the viewDRclone.ps1 script to bring the views online at ClusterB and protect them. To prepare for failback to ClusterA, specify a policy that replicates back to ClusterA.

```powershell
.\viewDRclone.ps1 -vip clusterB `
                  -username admin `
                  -domain local `
                  -tenant mytenant `
                  -viewList .\myviews.txt `
                  -policyName mypolicy `
                  -inPath '.'
```

## Delete the Old Views from ClusterA

Use the viewDRdelete.ps1 script to delete the old views from ClusterA

```powershell
.\viewDRdelete.ps1 -vip clusterA `
                   -username admin `
                   -domain local `
                   -tenant mytenant `
                   -viewList .\myviews.txt
```

## Clean Up Protection Groups on ClusterB

ClusterB will now have a new failover protection group, plus the old replicated protection group. Use the cleanupJobs.ps1 script to delete the old protection group, and rename the failover protection group to the original name.

```powershell
.\cleanupJobs.ps1  -vip clusterB `
                   -username admin `
                   -domain local `
                   -tenant mytenant `
                   -viewList .\myviews.txt
```

## Failback

Before attempting to failback to ClusterA, make sure to run viewDRcollect.ps1 again, to store the metadata of the views now on ClusterB.

```powershell
.\viewDRcollect.ps1 -vip clusterB `
                    -username admin `
                    -domain local `
                    -outPath '.'
```

Also make sure that the new protection group on ClusterB has finished replicating all views back to ClusterA. Then, we simply execute the clone, delete, and cleanup steps in reverse.

```powershell
.\viewDRclone.ps1 -vip clusterA `
                  -username admin `
                  -domain local `
                  -tenant mytenant `
                  -viewList .\myviews.txt `
                  -policyName mypolicy `
                  -inPath '.'

.\viewDRdelete.ps1 -vip clusterA `
                   -username admin `
                   -domain local `
                   -tenant mytenant `
                   -viewList .\myviews.txt

.\cleanupJobs.ps1  -vip clusterA `
                   -username admin `
                   -domain local `
                   -tenant mytenant `
                   -viewList .\myviews.txt
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

## Other Parameters

* -viewNames: (optional) one or more view names to process (comma separated)
* -viewList: (optional) text file of view names to process (one per line)
* -all: (optional) process all views on the cluster
* -policyName: (optional) policy name to protect views after cloning

## Authenticating to Helios

The Test/Wrapper scripts can be configured to log onto clusters directly, or log onto Helios.

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
