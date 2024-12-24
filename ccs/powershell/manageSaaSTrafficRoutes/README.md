# Manage SaaS Connector Traffic Routes using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script can assign or unassign vSphere entities to the specified SaaS connector group.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'manageSaaSTrafficRoutes'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [manageSaaSTrafficRoutes.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/manageSaaSTrafficRoutes/manageSaaSTrafficRoutes.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

List Assignments:

```powershell
./manageSaaSTrafficRoutes.ps1 -sourceName myvCenter.mydomain.net `
                              -connectionName 'My SaaS Connection'
```

Assign an entity to a connector group:

```powershell
./manageSaaSTrafficRoutes.ps1 -sourceName myvCenter.mydomain.net `
                              -connectionName 'My SaaS Connection' `
                              -groupName 'Site A' `
                              -entityName 'Datacenter1/cluster1/host1'
```

Unassign an entity:

```powershell
./manageSaaSTrafficRoutes.ps1 -sourceName myvCenter.mydomain.net `
                              -connectionName 'My SaaS Connection' `
                              -unassign `
                              -entityName 'Datacenter1/cluster1/host1'
```

List all entities:

```powershell
./manageSaaSTrafficRoutes.ps1 -sourceName myvCenter.mydomain.net `
                              -connectionName 'My SaaS Connection' `
                              -listEntities
```

## Parameters

* -username: (optional) username to connect to Helios (default is 'Ccs')
* -password: (optional) API key to connect to Helios (will be prompted if omitted and not already stored)
* -sourceName: name of VMware protection source
* -connectionName: name of SaaS Connection to manage
* -groupName: (optional) name of connector group to assign to
* -entityName: (optional) name of VMware entity to assign/unassign
* -unassign: (optional) unassign entity from connector groups
* -listEntities: (optional) display list of available VMware entitie
* -vcUsername: (optional) vCenter source registration username (will use existing username if omitted)
* -vcPassword: (optional) vCenter source registration password (will be prompted of omitted)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
