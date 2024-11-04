# Gather Average VM Disk Throughput Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script collects average VM disk throughput needed to size CDP solutions. This script requires vSphere PowerCLI.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'vmAvgDiskThroughput'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Components

* [vmAvgDiskThroughput.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/vmAvgDiskThroughput/vmAvgDiskThroughput.ps1): the main powershell script

Place both files in a folder together and run the main script like so:

```powershell
./vmAvgDiskThroughput.ps1 -vCenter myvcenter.mydomain.net `
                          -vmName vm1, vm2 `
                          -vmList ./vmlist.txt
```

## Parameters

* -vCenter: vCenter to connect to
* -vmName: (optional) names of VMs to query (comma separated)
* -vmList: (optional) text file of VMs to query (one per line)
