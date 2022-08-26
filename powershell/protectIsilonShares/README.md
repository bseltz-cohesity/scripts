# Protect Isilon Shares Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates a protection job for every Isilon share read from a text file

## Components

* protectIsilonShares.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module
* shares.txt: a text file containing a list of share names from the Isilon

Place all files in a folder together. Create a text file called shares.txt and populate with the shares that you want to protect, like so:

```text
share1
share2
share3
```

Then, run the main script like so:

```powershell
./protectIsilonShares.ps1 -vip mycluster -username myusername -policyName 'My Policy' -isilon Isilon1
```

```text
Connected!
Creating Job Isilon-share1...
Creating Job Isilon-share2...
Creating Job Isilon-share3...
```

## Optional Parameters

* -domain: your AD domain (defaults to local)
* -shareList: name of the text file (defaults to shares.txt)
* -storageDomain: name of the storage domain (defaults to DefaultStorageDomain)
* -startTime: in military format 'HH:MM' defaults to '22:00'

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectIsilonShares'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```
