# REST API Cheat Sheet

How to enable yourself to demo the Cohesity REST API

## Install PowerShell Core on your Mac 

Download the PowerShell Cofre .pkg file for MacOS here: https://github.com/PowerShell/PowerShell#get-powershell

After installation you can launch powershell from a terminal session with the command:

```bash
  pwsh
```

## Install the Cohesity PowerShell Module

To install the Cohesity PowerShell cmdlets, run the following command from within your new PowerShell session.

Installing for the first time:
```powershell
>  Install-Module -Name Cohesity.PowerShell.Core
```

Upgrading to the latest version:
```powershell
>  Update-Module -Name Cohesity.PowerShell.Core
```

**Note**: On Windows, using full PowerShell (not Core), install the Cohesity.PowerShell module instead of Cohesity.PowerShell.Core

## Connect to a Cohesity Cluster

```powershell
> Connect-CohesityCluster -Server mycluster              

Supply values for the following parameters:
User: admin
Password for user admin: *****

Connected to the Cohesity Cluster mycluster Successfully
```
once connected, you can run other cmdlets:
```powershell
> Get-CohesityProtectionJob

Id    Name              Environment    LastRunTime         SLA  IsPaused
--    ----              -----------    -----------         ---  --------
7     VM Backup         kVMware        1/23/19 11:30:00 PM Pass False
35    Oracle            kOracle        1/24/19 12:00:00 AM Pass False
841   Generic NAS       kGenericNas    1/24/19 12:10:00 AM Pass False
6222  File-Based Backup kPhysicalFiles 1/24/19 12:40:01 AM Pass False
8028  SQL Backup        kSQL           1/24/19 03:03:58 AM Pass False
12886 Scripts           kView          1/24/19 12:30:01 AM Pass False
```

Check out all the Cohesity cmdlets:

```powershell
>  Get-Command *Cohesity* | ft -Property name, version
```

or view a synopsis of what each cmdlet does:

```powershell
>  Get-Help *Cohesity* | ft -Property Name, Synopsis  
```

Example, run an on-demand backup:

```powershell
>  $job = Get-CohesityProtectionJob -Names 'VM Backup'
>  Start-CohesityProtectionJob -Id $job.Id
Protection job was started successfully.
```

Find the Cohesity PowerShell Module documentation and more examples at: https://cohesity.github.io/cohesity-powershell-module/#/README
