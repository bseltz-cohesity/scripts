# List Logical Usage per Object using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script displays the logical size of live views and protected objects.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/logicalUsage/logicalUsage.ps1).content | Out-File logicalUsage.ps1; (Get-Content logicalUsage.ps1) | Set-Content logicalUsage.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/logicalUsage/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* logicalUsage.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together and run the main script like so:

```powershell
./logicalUsage.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net
```

```text
Connected!
Inspecting snapshots...
Inspecting Views...

    Environment   Size (GB)  Name
    ===========   =========  ====
          kView         824  archive
        kVMware         220  vRA-IAAS
        kVMware         210  win2012-sql
        kVMware         100  pb-win01
        kVMware          66  centos-vm
        kVMware          66  centosTB-vm
        kVMware          64  WindowsBT
          kView           5  share
          kView           2  heart-view
          kView           2  Matt1

    Total Logical Size: 2,704 GB
```

By default, the script will search back 90 days to find the peak size of any object still in retention. If you have retention greater than 90 days, you can include the -days parameter, like:

```powershell
./logicalUsage.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -days 120
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -days: (optional) number of days to look back (default is 90 days)
