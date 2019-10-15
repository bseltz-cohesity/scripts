# Register a list of Generic NAS Sources using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script registers a list of generic NAS shares as sources on Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/registerGenericNasList/registerGenericNasList.ps1).content | Out-File registerGenericNasList.ps1; (Get-Content registerGenericNasList.ps1) | Set-Content registerGenericNasList.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/registerGenericNasList/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* registerGenericNasList.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./registerGenericNasList.ps1 -vip mycluster -username myusername -domain mydomain.net -nasList mynaslist.txt -smbUserName mydomain.net\myusername
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -nasList: path to text file containing list of NAS shares to register
* -smbUserName: SMB username to connect to SMB shares, e.g. mydomain\myusername
