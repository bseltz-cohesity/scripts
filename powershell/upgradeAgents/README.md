# Upgrade Cohesity Agents using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script detects and upgrades any upgradable agents for physical protection sources registered to the Cohesity cluster.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'upgradeAgents'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* upgradeAgents.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

To report on current upgradability of all hosts

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -all
```

To perform the upgrade on all upgradable hosts:

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -all `
                    -upgrade
```

To specify a few hosts on the command line:

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -serverNames server1.mydomain.net, server2.mydomain.net `
                    -upgrade
```

or use a text file (one server per line):

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -serverList ./myservers.txt `
                    -upgrade
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -serverNames: one or more servers (comma separated) to report or upgrade
* -serverList: file containing list of servers
* -all: report or upgrade all servers
* -upgrade: perform upgrades (just report if omitted)
