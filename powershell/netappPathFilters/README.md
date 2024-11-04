# Add NetApp Inclusion and Exclusion Paths using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds inclusion and exclusion paths to a NetApp protection job.

The script will add to existing inclusions/exclusions (existing exclusions will be preserved, and new ones will be added).

## Components

* [netappPathFilters.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/netappPathFilters/netappPathFilters.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together (see download instructions below). The script takes a list of one or more inclusion or exclusion paths via the PowerShell input pipeline. For example to add inclusion paths:

```powershell
"/vol1/share2" | ./netappPathFilters.ps1 -vip mycluster -username myusername -jobName NetAppJob -addInclusions

# or

"/vol1/share2", "/vol1/share3" | ./netappPathFilters.ps1 -vip mycluster -username myusername -jobName NetAppJob -addInclusions

# or

Get-Content ./inclusions.txt | ./netappPathFilters.ps1 -vip mycluster -username myusername -jobName NetAppJob -addInclusions
```

```text
Connected!
adding to include list: /vol1/share2
adding to include list: /vol1/share3
```

Similarly, you can add exclusion paths in the same way, using the -addExclusions parameter

```powershell
"/vol1/share2/skip" | ./netappPathFilters.ps1 -vip mycluster -username myusername -jobName NetAppJob -addExclusions

# or

"/vol1/share2/skip", "/vol1/share3/junk" | ./netappPathFilters.ps1 -vip mycluster -username myusername -jobName NetAppJob -addExclusions

# or

Get-Content ./exclusions.txt | ./netappPathFilters.ps1 -vip mycluster -username myusername -jobName NetAppJob -addExclusions
```

```text
Connected!
adding to exclude list: /vol1/share2/skip
adding to exclude list: /vol1/share3/junk
```

Duplicate entries will be ignored.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'netappPathFilters'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```
