# Upgrade Cohesity Agents using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script detects and upgrades any upgradable agents for physical protection sources registered to the Cohesity cluster. This script can be run from anywhere that can connect to the Cohesity clusters(s) or can connect to helios.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'upgradeAgents'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [upgradeAgents.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/upgradeAgents/upgradeAgents.ps1): the main PowerShell script - md5 checksum: e005ea935929a5283c90db7a73d3942a
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module - md5 checksum: 6713f57c974e5acc8ee0075c3f1fb6bf

Place all files in a folder together, then run the main script like so:

To report on current upgradability of all agents:

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain local # or mydomain.net for AD user
```

To perform the upgrade:

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain local `
                    -upgrade
```

To filter on OS type:

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain local `
                    -osType linux `
                    -upgrade
```

To specify a few hosts on the command line:

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain local `
                    -agentNames server1.mydomain.net, server2.mydomain.net `
                    -upgrade
```

or use a text file (one server per line):

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -agentList ./myservers.txt `
                    -upgrade
```

To perform a refresh:

```powershell
./upgradeAgents.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -skipWarnings `
                    -refresh
```

## Authentication Parameters

* -vip: (optional) one or more clusters to connect to (comma separated) (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -clusterName: (optional) one or more clusters (comma separated) to connect to when connecting through Helios (defaults to all helios clusters)
* -mfaCode: (optional) totp for MFA (only works when connecting directly to one cluster)

## Parameters

* -agentName: (optional) one or more protection source names to include (comma separated)
* -agentList: (optional) text file of protection source names to include (one per line)
* -osType: (optional) filter on OS type (e.g. windows, linux, aix)
* -skipWarnings: (optional) skip sources that have registration/refresh errors
* -upgrade: (optional) initiate agent upgrades (will just show status if omitted)
* -skipCurrent: (optional) do not display agents that are up to date
* -refresh: (optional) force refresh (this can be slow, recommend using -skipWarnings when using this)
* -throttle: (optional) number of upgrades to start before sleeping (default is 12)
* -sleepTime: (optional) number of seconds to wait after throttle limit is reached (default is 60)

## Authenticating to Helios

See official doc here: <https://docs.cohesity.com/WebHelios/Content/Helios/Access_Management.htm#ManageAPIKeys>

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon (settings) -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When connecting to helios, if you are prompted for a password, enter the API key as the password.
