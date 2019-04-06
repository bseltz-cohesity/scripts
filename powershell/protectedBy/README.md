# Find Job Protecting an Object Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script reports which protection job is protecting an object.

## Components

* protectedBy.ps1: the main python script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together (see download instructions below), and run the script like so:

```powershell
./protectedBy.ps1 -vip mycluster -username myuser -domain mydomain.net -object vm1
```

```text
Connected!
(kVMware) vm1 (29) is protected by VM Backup
```

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download instructions
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/protectedBy/protectedBy.ps1).content | Out-File protectedBy.ps1; (Get-Content protectedBy.ps1) | Set-Content protectedBy.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/protectedBy/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# end download instructions
```

