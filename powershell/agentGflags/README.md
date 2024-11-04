# List or Set Agent gFlags using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script lists or sets agent gFlags.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'agentGflags'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Components

* [agentGflags.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/agentGflags/agentGflags.ps1): the main powershell script

Run the main script like so:

To list agent gflags on a host:

```powershell
./agentGflags.ps1 -serverName myhost
```

To set a gflag:

```powershell
./agentGflags.ps1 -serverName myhost -flagName sql_allow_multiple_cohesity_clusters -flagValue true
```

To clear a gflag:

```powershell
./agentGflags.ps1 -serverName myhost -flagName sql_allow_multiple_cohesity_clusters -clear
```

## Parameters

* -serverName: one or more servers (comma separated) to manage
* -serverList: file containing list of servers to manage
* -flagName: name of gFlag to set or clear
* -flagValue: value to set for gFlag
* -clear: remove the specified gFlag
* -restart: restart Cohesity agent
