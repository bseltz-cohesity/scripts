# Cohesity REST API Cheat Sheet

Enable yourself to demo the Cohesity REST API

## Install PowerShell Core on your Mac 

Download the PowerShell Core .pkg file for MacOS here: https://github.com/PowerShell/PowerShell#get-powershell

After installation you can launch PowerShell from a terminal session with the command:

```bash
  pwsh
```

## Install the Cohesity PowerShell Module

To install the Cohesity PowerShell cmdlets, run the following command from within your new PowerShell session.

**Note**: On Windows, the Desktop edition of PowerShell (not Core) is usually installed. If so, install Cohesity.PowerShell instead of Cohesity.PowerShell.Core. You can see what edition you have by typing in PowerShell:

```powershell
>  $PSVersionTable.PSEdition
Desktop #or Core
```

Install the Cohesity PowerShell Module:

```powershell
   #first time install
>  Install-Module -Name Cohesity.PowerShell.Core
   #or upgrade to the latest version
>  Update-Module -Name Cohesity.PowerShell.Core
```

## Connect to a Cohesity Cluster

```powershell
> Connect-CohesityCluster -Server mycluster              

Supply values for the following parameters:
User: admin
Password for user admin: *****
```

Once connected, you can run other cmdlets:

```powershell
> Get-CohesityProtectionJob

Id    Name              Environment    LastRunTime         SLA  IsPaused
--    ----              -----------    -----------         ---  --------
7     VM Backup         kVMware        1/23/19 11:30:00 PM Pass False
35    Oracle            kOracle        1/24/19 12:00:00 AM Pass False
841   Generic NAS       kGenericNas    1/24/19 12:10:00 AM Pass False
...
```

Check out all the Cohesity cmdlets:

```powershell
>  Get-Command *Cohesity* | ft -Property name, version
>  #or
>  Get-Help *Cohesity* | ft -Property Name, Synopsis
```

Run an on-demand backup:

```powershell
>  $job = Get-CohesityProtectionJob -Names 'VM Backup'
>  $job | Start-CohesityProtectionJob
Protection job was started successfully.
```

Find the Cohesity PowerShell Module documentation and more examples here: https://cohesity.github.io/cohesity-powershell-module/#/README


## More Resources

* Cohesity Developer Portal: https://developer.cohesity.com/#/rest/getting-started
* REST API Browser (Swagger): https://mycluster/docs/restApiDocs/browse/
* REST API Documentation (public): https://mycluster/docs/restApiDocs/bootprint/
* REST API Documentation (internal): https://mycluster/docs/restApiDocs/bootprintinternal/
* REST API Documentation PDFs: https://drive.google.com/drive/folders/1HMSNLAxIRGJ4WBXTRI07LXXSTAC1w3iB?usp=sharing

* BSeltz's Favorite PowerShell Book: https://www.amazon.com/Windows-PowerShell-Action-Bruce-Payette/dp/1633430294