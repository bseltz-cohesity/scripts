# Register New Physical Protection Source using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script registers a new physical host as a Cohesity protection source.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/new-PhysicalSource/new-PhysicalSource.ps1).content | Out-File new-PhysicalSource.ps1; (Get-Content new-PhysicalSource.ps1) | Set-Content new-PhysicalSource.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/new-PhysicalSource/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* new-PhysicalSource.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then run the script like so.

```powershell
./new-PhysicalSource.ps1 -vip mycluster -username admin -server win2016.mydomain.com
Connected!
New Physical Server Registered. ID: 597
```

```powershell
./new-PhysicalSource.ps1 -vip mycluster -username admin -server 192.168.1.10
Connected!
New Physical Server Registered. ID: 593
```

Note that the Cohesity agent must be installed on the host and that firewall port 50051/tcp on the host must be accessible by the Cohesity cluster. 