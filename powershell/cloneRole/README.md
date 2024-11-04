# Clone a Role using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones a role, creating a new role with the same privileges.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneRole'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneRole.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cloneRole/cloneRole.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
./cloneRole.ps1 -vip mycluster -username admin [ -domain local ] -roleName role1 -newRoleName role2
# end example
```

## Parameters

* -vip: DNS or IP of the Cohesity Cluster
* -username: Cohesity User Name
* -domain: (optional) AD domain of Cohesity user (defaults to local)
* -roleName: name of role to clone
* -newRoleName: (optional) name of new role to create
* -targetCluster: (optional) clone role to another cluster
* -targetUsername: (optional) username for target cluster
* -targetDomain: (optional) user domain for target cluster (default is local)
