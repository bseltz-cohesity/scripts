# Auto Protect VMs by Container using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script auto protects VMs by container. A Container can be a datacenter, cluster, host or folder.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectVMsByContainer'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectVMsByContainer.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectVMsByContainer/protectVMsByContainer.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To autoprotect a vSphere cluster:

```powershell
./protectVMsByContainer.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -vCenterName myvcenter.mydomain.net `
                            -dataCenter myDataCenter `
                            -jobName 'vm backup' `
                            -objectName myHACluster1
```

To autoprotect a folder:

```powershell
./protectVMsByContainer.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -vCenterName myvcenter.mydomain.net `
                            -dataCenter myDataCenter `
                            -jobName 'vm backup' `
                            -objectName myfolder1
```

If a folder is nested, you can specify the canonical folder path:

```powershell
./protectVMsByContainer.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -vCenterName myvcenter.mydomain.net `
                            -dataCenter myDataCenter `
                            -jobName 'vm backup' `
                            -objectName 'myfolder1/mysubfolder'
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -helios: (optional) connect through MCM/Helios OnPrem
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -objectName: (optional) one or more containers (comma separated) to add to the proctection job
* -objectList: (optional) file containing list of containers to add
* -jobName: name of protection job
* -dataCenter: name of vSphere data center to search in
* -listContainers: (optional) list available containers and exit

## Parameters for New Jobs Only

* -vCenterName: (optional) name of registered vCenter source
* -policyName: (optional) name of the protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
* -disableIndexing: (optional) disable indexing (indexing is enabled by default)
