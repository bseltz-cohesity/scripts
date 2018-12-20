# Recover a NAS Share using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a protected NAS share to a Cohesity View.

## Components

* recoverNas.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then run the script like so:

```powershell
powershell> ./recoverNas.ps1 -vip mycluster -username admin -shareName \\netapp1.mydomain.net\share1 -viewName share1            
Connected!
Recovering \\netapp1.mydomain.net\share1 as view share1
```