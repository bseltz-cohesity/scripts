# Recover a NAS Share using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a protected NAS share to a Cohesity View.

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/recoverNas/recoverNas.ps1).content | Out-File recoverNas.ps1; (Get-Content recoverNas.ps1) | Set-Content recoverNas.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* recoverNas.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then run the script like so:

```powershell
powershell> ./recoverNas.ps1 -vip mycluster -username admin -shareName \\netapp1.mydomain.net\share1 -viewName share1 -sourceName mynetapp
Connected!
Recovering \\netapp1.mydomain.net\share1 as view share1
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity logon username
* -domain: (optional) Cohesity logon domain (defaults to local)
* -shareName: name of protected NAS share to be recovered
* -viewName: name of Cohesity view to recover to
* -sourceName: (optional) name of protected NAS source

## Notes

The format of Isilon shares is different, so recovering an Isilon share looks like this:

```powershell
powershell> ./recoverNas.ps1 -vip mycluster -username admin -shareName /ifs/share1 -viewName share1
Connected!
Recovering /ifs/share1 as view share1
```

If you have two Isilon arrays and they both have an /ifs/share1 on them, then you can use the -sourceName parameter to specify which one you want to recover:

```powershell
powershell> ./recoverNas.ps1 -vip mycluster -username admin -shareName /ifs/share1 -viewName share1 -sourceName Isilon1
Connected!
Recovering /ifs/share1 as view share1
```

If you are using an Active Directory account to log onto Cohesity, use the -username and -domain parameters like this:

```powershell
powershell> ./recoverNas.ps1 -vip mycluster -username myusername -domain mydomain.net -shareName /ifs/share1 -viewName share1 -sourceName Isilon1
Connected!
Recovering /ifs/share1 as view share1
```
