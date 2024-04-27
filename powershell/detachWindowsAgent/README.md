# Detach Windows Agent from Cluster using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell decouples a Windows agent from a cohesity cluster so that it can be registered to another cluster.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'detachWindowsAgent'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Components

* [detachWindowsAgent.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/detachWindowsAgent/detachWindowsAgent.ps1): the main powershell script

## Examples

```powershell
./detachWindowsAgent.ps1 -serverName myserver1
```

```powershell
./detachWindowsAgent.ps1 -serverName myserver1, myserver2
```

```powershell
./detachWindowsAgent.ps1 -serverList ./myservers.txt
```

## Parameters

* -serverName: one or more servers to detach (comma separated)
* -serverList: a text file list of servers to detach (one per line)
