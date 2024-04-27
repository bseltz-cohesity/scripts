# Delete a Protection Job using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script deletes a protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'deleteProtectionJob'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [deleteProtectionJob.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deleteProtectionJob/deleteProtectionJob.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./deleteProtectionJob.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName myjob
```

To also delete the existing snapshots:

```powershell
./deleteProtectionJob.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName myjob `
                          -deleteSnapshots
```

To delete the existing snapshhots for a job that has already been deleted:

```powershell
./deleteProtectionJob.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName _DELETED_myjob `
                          -deleteSnapshots
```

To specify more than one job to process, you can provide multiple job names on the command line:

```powershell
./deleteProtectionJob.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName myjob1, myjob2 `
                          -deleteSnapshots
```

Or provide a text file of job names (one per line):

```powershell
./deleteProtectionJob.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobList .\myjobs.txt `
                          -deleteSnapshots
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

* -jobName: (optional) comma separated list of job names to delete
* -jobList: (optional) text file containing job names to delete (one per line)
* -deleteSnapshots: (optional) delete existing snapshots (snapshots are reteined by default)
