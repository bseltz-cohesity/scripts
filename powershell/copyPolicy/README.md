# Import and Export Cohesity Protection Policies Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script exports or imports a protection policy (to copy policies between clusters). The major caveat is that snapshot copy policy elements (replications, archives, cloudSpins) are not copied (because they are likely not the same from one cluster to the next).

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'copyPolicy'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/copyPolicy.ps1").content | Out-File "copyPolicy.ps1"; (Get-Content "copyPolicy.ps1") | Set-Content "copyPolicy.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* copyPolicy.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

## Exporting Objects

Place all files in a folder together. You can run the copyPolicy.ps1 script like so:

To export a policy

```powershell
./copyPolicy.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net `
                 -policyName 'my policy' `
                 -export
```

To import the policy on another cluster and keep the same policy name:

```powershell
./copyPolicy.ps1 -vip anothercluster `
                 -username myusername `
                 -domain mydomain.net `
                 -policyName 'my policy' `
                 -import
```

Or to import the policy with a new name:

```powershell
./copyPolicy.ps1 -vip anothercluster `
                 -username myusername `
                 -domain mydomain.net `
                 -policyName 'my policy' `
                 -newPolicyName 'new policy' `
                 -import
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -policyName: name of policy to export/import
* -export: (optional) export the policy named in -policyName
* -import: (optional) import the policy named in -policyName
* -newPolicyName: (optional) rename the policy during import
* -configFolder: (optional) Defaults to .\configExports
