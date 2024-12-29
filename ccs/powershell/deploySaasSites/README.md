# Deploy SaaS Sites using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a powershell wrapper script to perform the following:

1. Deploy a SaaS Connector and register it to CCS
2. Register an ESXi host and link it to the SaaS Connection
3. Autoprotect the ESXi host

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'deploySaasSites'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [deploySaasSites.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/deploySaasSites/deploySaasSites.ps1): the main powershell wrapper script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* [deploySaaSConnector.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/deploySaaSConnector/deploySaaSConnector.ps1): deploy SaaS Connector script
* [registerESXiHostCCS.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/registerESXiHostCCS/registerESXiHostCCS.ps1): register ESXi Host script
* [protectCcsVMs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/protectCcsVMs/protectCcsVMs.ps1): protect VMs script
* [siteDeploy.csv](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/deploySaasSites/siteDeploy.csv): example CSV file

Place all files in the same folder. Modify the CSV file to suite your environment, then run the script like so:

```powershell
.\deploySaasSites.ps1 -csvFile .\siteDeploy.csv `
                      -connect `
                      -protect
```

## Parameters

* -username: (optional) username to connect to Helios (default is 'Ccs')
* -password: (optional) API key to connect to Helios (will be prompted if omitted and not already stored)
* -saasConnectorPassword: (optional) new admin password for SaaS Connector (will be prompted if omitted)
* -esxiPassword: (optional) registration password for ESXi host (will be prompted if omitted)
* -csvFile: path to CSV file containing site information
* -connect: (optional) deploy SaaS connector
* -protect: (optional) register and protect ESXi host

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
