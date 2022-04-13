# Protect DMaaS AWS EC2 VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script protects DMaaS AWS EC2 VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectDmaasEC2VMs'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -Uri "$repoUrl/dmaas/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* protectDmaasEC2VMs.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectDmaasEC2VMs.ps1 -region us-east-2 `
                         -policyName Gold `
                         -sourceName 23423423423 `
                         -vmNames myvm1, myvm2 `
                         -vmList ./vmlist.txt
```

## Parameters

* -username: (optional) used for password storage only (default is 'DMaaS')
* -region: DMaaS region to use
* -sourceName: name of registered M365 protection source
* -policyName: name of protection policy to use
* -vmNames: (optional) one or more VM names (comma separated)
* -vmList: (optional) text file of VM names (one per line)
* -protectionType: (optional) CohesitySnapshot, AWSSnapshot or All (default is CohesitySnapshot)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120

## Authenticating to DMaaS

DMaaS uses an API key for authentication. To acquire an API key:

* log onto DMaaS
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a DMaaS compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
