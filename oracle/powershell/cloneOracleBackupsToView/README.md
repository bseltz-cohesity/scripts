# Clone Oracle Backup Files to a View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones backup files to a Cohesity view.

## Warning! This script can delete views! Make sure you know what you are doing before you run it

## Download the Scripts

Run these commands from PowerShell to download the scripts into the current folder:

```powershell
# Download Commands
$scriptName = 'cloneOracleBackupsToView'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/oracle/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneOracleBackupsToView.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/cloneOracleBackupsToView/cloneOracleBackupsToView.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

To clone all available backups:

```powershell
./cloneOracleBackupsToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobName 'My Oracle Job' `
                        -objectName myoracleserver.mydomain.net `
                        -viewName cloned
```

To limit access to specific users:

```powershell
./cloneOracleBackupsToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobName 'My Oracle Job' `
                        -objectName myoracleserver.mydomain.net `
                        -viewName cloned `
                        -access 'mydomain.net\domain admins', mydomain.net\othergroup
```

To delete a view when finished:

```powershell
./cloneOracleBackupsToView.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -viewName cloned `
                        -deleteView
```

To refresh a view (on a schedule):

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

## Other Parameters

* -jobname: name of Oracle protection job
* -objectName: (optional) name of Oracle Server whose backup to clone
* -viewName: (optional) name of new or existing view to clone backup files to
* -numRuns: (optional) max number of runs to clone (default is 100)
* -deleteView: (optional) delete view when finished
* -force: (optional) do not prompt for confirmation when refreshing or deleting view (DANGEROUS!)

## Parameters for View Access

* -access: (optional) Active Directory users/groups (comma separated) to add to share permissions (default is everyone)
* -ips: (optional) cidrs to add, examples: 192.168.1.3/32, 192.168.2.0/24 (comma separated)
* -ipList: (optional) text file of cidrs to add (one per line)
* -readOnly: (optional) readWrite if omitted
