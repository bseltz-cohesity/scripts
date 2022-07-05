# Clone a Cohesity DR View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones a replicated view.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'cloneDRView'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* cloneDRView.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./cloneDRView.ps1 -vip mycluster -username myusername -domain mydomain.net -viewName MyView -newName MyClonedView
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -viewName: Name of the replicated view to clone
* -newName: Name to assign to new cloned view
* -qosPolicy: (optional) QoS policy selection (defaults to 'TestAndDev High')
* -whiteList: (optional) list of whitelist overrides

## Whitelist entries

IF you want to add whitelist overrides, you can add them using the -whiteList parameter. For example:

```powershell
-whiteList @{'ip'='192.168.1.0'; "netmaskIp4" = "255.255.255.0";  "description" = "Home"}, @{'ip'='10.0.1.0'; "netmaskIp4" = "255.255.255.0"}
```
