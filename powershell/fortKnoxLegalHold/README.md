# Set Legal Hold on FortKnox Vault Copies using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

Contributed by: Guna Chidambaram

This script adds, removes, or reports Data Protect legal hold on existing
FortKnox cloud-vault copies.

this script:

* selects only archival targets whose ownership context is FortKnox/RPaaS;
* sends a legal-hold-only for FortKnox archives only, without local snapshot or retention changes.

The account must have the Data Security privilege and permission to modify the
protection run. A custom role should include both `DATA_SECURITY` and
`PROTECTION_MODIFY`.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'fortKnoxLegalHold'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'fortKnoxLegalHoldV2'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/fortKnoxLegalHold/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [fortKnoxLegalHold.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/fortKnoxLegalHold/fortKnoxLegalHold.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## List FortKnox vaulted copies

```powershell
./fortKnoxLegalHold.ps1 -vip mycluster `
                        -username datasec `
                        -jobName 'my protection group' `
                        -listRuns
```

When connecting through Helios or MCM, also specify `-clusterName`.

The output includes the v2 `RunId`, FortKnox vault ID/name, current legal-hold
state, and expiry date. Use the displayed `RunId` for updates.

## Add legal hold

```powershell
./fortKnoxLegalHold.ps1 -vip mycluster `
                        -username datasec `
                        -jobName 'my protection group' `
                        -runId '12345:1609459200000000' `
                        -vaultName 'my-fortknox-vault' `
                        -addHold
```

## Remove legal hold

```powershell
./fortKnoxLegalHold.ps1 -vip mycluster `
                        -username datasec `
                        -jobName 'my protection group' `
                        -runId '12345:1609459200000000' `
                        -vaultName 'my-fortknox-vault' `
                        -removeHold
```

Removing legal hold after the original retention expiry may make the vaulted
copy immediately eligible for expiration.

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (required) name of protection group to operate on
* -listRuns: (optional) list runs available to operation
* -runId: (optional) target specific run ID
* -removeHold: (optional) remove legal hold from targeted runs
* -addHold: (optional) add legal hold to targeted runs
* -latest: (optional) select latest run
* -startDate: (optional) specify start date for range of runs
* -endDate: (optional) specify end date for range of runs
* -vaultId: (optional) specify vault ID
* -vaultName: (optional) specify vault name
* -numRuns: (optional) max number of runs to query (default is 1000)
