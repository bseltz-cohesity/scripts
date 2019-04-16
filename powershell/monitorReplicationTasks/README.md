# Monitor Replication Tasks using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script monitors replication tasks.

## Components

* monitorReplicationTasks.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./monitorReplicationTasks.ps1 -vip mycluster -username myusername -domain mydomain.net
```

```text
Connected!
Looking for Replication Tasks...
04/16/2019 05:24:04  Ubuntu  -> kAccepted
```

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/monitorReplicationTasks/monitorReplicationTasks.ps1).content | Out-File monitorReplicationTasks.ps1; (Get-Content monitorReplicationTasks.ps1) | Set-Content monitorReplicationTasks.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/monitorReplicationTasks/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```
