# List Cohesity Users and Groups Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script lists users and groups and writes the output to a text file (addObjectToUserAccessList-clusterName.txt)  

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'addObjectToUserAccessList'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* addObjectToUserAccessList.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
# Command line example
./addObjectToUserAccessList.ps1 -vip mycluster `
                                -username myuser `
                                -domain mydomain.net `
                                -principal mydomain.net/myuser `
                                -addObject vm1, server1.mydomain.net `
                                -removeObject vm2, vm3 `
                                -addView view1, view2 `
                                -removeView view3, view4
# End example
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Cohesity logon domain (defaults to local)
* -principal: name(s) (comma separated) of user or group to modify (e.g. mydomain.net/myuser, or mylocaluser) `
* -addObject: (optional) names of registered objects to add to access list (comma separated)
* -removeObject: (optional) names of registered objects to remove from access list (comma separated)
* -addView: (optional) names of views to add to access list (comma separated)
* -removeView: (optional) names of views to remove from access list (comma separated)
