# Add Objects and Views to User Access List Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds registered objects and views to a user/group restricted access list.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'addObjectToUserAccessList'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [addObjectToUserAccessList.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addObjectToUserAccessList/addObjectToUserAccessList.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
# Command line example
./addObjectToUserAccessList.ps1 -vip mycluster `
                                -username myuser `
                                -domain mydomain.net `
                                -principalName mydomain.net/myuser `
                                -sourceName myvcenter.mydomain.net `
                                -objectName vm1, vm2
# End example

# Command line example
./addObjectToUserAccessList.ps1 -vip mycluster `
                                -username myuser `
                                -domain mydomain.net `
                                -principalName mydomain.net/myuser `
                                -sourceName mysqlserver.mydomain.net
# End example

# Command line example
./addObjectToUserAccessList.ps1 -vip mycluster `
                                -username myuser `
                                -domain mydomain.net `
                                -principalName mydomain.net/myuser `
                                -viewName view1, view2
# End example
```

Add all registered SQL sources to a user's access list:

```powershell
# Command line example: all sources of a type
./addObjectToUserAccessList.ps1 -vip mycluster `
                                -username myuser `
                                -domain mydomain.net `
                                -principalName mydomain.net/myuser `
                                -allOfType kSQL
# End example
```

Use text files to specify principals, objects and views:

```powershell
# Command line example: lists from files
./addObjectToUserAccessList.ps1 -vip mycluster `
                                -username myuser `
                                -domain mydomain.net `
                                -principalList ./principals.txt `
                                -objectList ./objects.txt `
                                -viewList ./views.txt
# End example
```

Apply the same change to multiple clusters by listing them in `-vip`:

```powershell
# Command line example: multiple clusters
./addObjectToUserAccessList.ps1 -vip mycluster1, mycluster2, mycluster3 `
                                -username myuser `
                                -domain mydomain.net `
                                -principalName mydomain.net/myuser `
                                -allOfType kSQL
# End example
```

Connect to Helios (the default when `-vip` is omitted) and apply the change to every connected cluster:

```powershell
# Command line example: all Helios clusters
./addObjectToUserAccessList.ps1 -username myuser@mydomain.net `
                                -useApiKey `
                                -principalName mydomain.net/myuser `
                                -allOfType kSQL
# End example
```

Limit the change to specific Helios clusters with `-clusterName`:

```powershell
# Command line example: selected Helios clusters
./addObjectToUserAccessList.ps1 -clusterName mycluster1, mycluster2 `
                                -username myuser@mydomain.net `
                                -useApiKey `
                                -principalName mydomain.net/myuser `
                                -allOfType kSQL
# End example
```

Remove all sources of a type from a user's access list on selected Helios clusters:

```powershell
# Command line example: remove across selected Helios clusters
./addObjectToUserAccessList.ps1 -clusterName mycluster1, mycluster2 `
                                -username myuser@mydomain.net `
                                -useApiKey `
                                -principalName mydomain.net/myuser `
                                -allOfType kSQL `
                                -remove
# End example
```

## Authentication Parameters

* -vip: (optional) one or more names or IPs of Cohesity clusters, comma separated (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) one or more clusters, comma separated, to connect to when connecting through Helios or MCM

## Parameters

* -principalName: (optional) users or groups to modify (comma separated) e.g. mydomain.net\myuser, mylocaluser `
* -principalList: (optional) text file of users or groups to modify (one per line)
* -sourceName: (optional) name of protection source that owns the objects (e.g. VMs) to be added
* -objectName: (optional) registered objects to add/remove from access list (comma separated)
* -objectList: (optional) text file of registered objects to add/remove from access list (one per line)
* -allOfType: (optional) add/remove all sources of the type specified (e.g. kSQL)
* -environment: (optional) find object of type (e.g. kPhysical, kVMware)
* -viewName: (optional) views to add/remove from access list (comma separated)
* -viewList: (optional) text file of views to add/remove from access list (one per line)
* -remove: (optional) perform remove operation (default is add)
