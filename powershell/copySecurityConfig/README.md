# Copy Account Security Configuration from One Cluster to Another Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script copies the account security configuration from one cluster to another.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'copySecurityConfig'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [copySecurityConfig.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/copySecurityConfig/copySecurityConfig.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To copy certs from one cluster to another:

```powershell
# example
./copySecurityConfig.ps1 -sourceCluster mycluster1 `
                         -sourceUser myuser1 `
                         -targetCluster mycluster2 `
                         -targetUser myuser2
# end example
```

## Parameters

* -sourceCluster: (optional) name or IP of source Cohesity cluster
* -sourceUser: (optional) name of user to connect to source cluster
* -sourceDomain: (optional) your AD domain (defaults to local)
* -targetCluster: name or IP of source Cohesity cluster
* -targetUser: name of user to connect to source cluster
* -targetDomain: (optional) your AD domain (defaults to local)
* -useApiKeys: (optional) use API keys for authentication
* -promptForMfaCode: (optional) prompt for MFA codes
