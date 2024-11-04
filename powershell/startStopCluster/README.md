# Start and Stop Cluster Services Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script starts and stops the cluster.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'startStopCluster'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [startStopCluster.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/startStopCluster/startStopCluster.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

```powershell
./startStopCluster.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -start `
                       -wait
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) password or API key (will use stored password by default)
* -mfaCode: (optional) multi-factor authentication code
* -emailMfaCode: (optional) send mfaCode via email
* -start: (optional) start the cluster
* -stop: (optional) stop the cluster
* -wait: (optional) wait for completion before exit
