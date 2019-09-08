# Capacity Tools for PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

Here is a suite of powershell scripts to help identify and clean up capacity consumption on your Cohesity cluster.

## Download the scripts

Run these commands from PowerShell to download the scripts into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cloneList/cloneList.ps1).content | Out-File cloneList.ps1; (Get-Content cloneList.ps1) | Set-Content cloneList.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/expireOldSnaps/expireOldSnaps.ps1).content | Out-File expireOldSnaps.ps1; (Get-Content expireOldSnaps.ps1) | Set-Content expireOldSnaps.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/logicalUsage/logicalUsage.ps1).content | Out-File logicalUsage.ps1; (Get-Content logicalUsage.ps1) | Set-Content logicalUsage.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/snapshotList/snapshotList.ps1).content | Out-File snapshotList.ps1; (Get-Content snapshotList.ps1) | Set-Content snapshotList.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/storageChart/storageChart.ps1).content | Out-File storageChart.ps1; (Get-Content storageChart.ps1) | Set-Content storageChart.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cloneList/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

Generate a storage growth chart (HTML5):

```powershell
.\storageChart.ps1 -vip mycluster `
                   -username myuser `
                   -domain mydomain.net `
                   -days 100
```

List the snapshots present on the cluster:

```powershell
./snapshotList.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net
```

List the clones (VMs and Databases) present on the cluster:

```powershell
./cloneList.ps1 -vip mycluster `
                -username myusername `
                -domain mydomain.net
```

List protected objects and views by logical usage:

```powershell
./logicalUsage.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net
```

Expire snapshots older than 90 days:

```powershell
./expireOldSnaps.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -daysToKeep 90 `
                     -expire
```
