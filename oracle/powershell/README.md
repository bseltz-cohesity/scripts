# Download the Cohesity Oracle PowerShell Scripts

There are four Oracle related scripts that are often useful to Oracle DBAs. They are:

* restoreOracle.ps1: restore an Oracle database for operational recovery or testing
* cloneOracle.ps1: clone an Oracle database for test/dev
* destroyClone.ps1: tear down an Oracle clone
* backupNow.ps1: perform an on demand backup

You can download these scripts onto your PC by opening a PowerShell session and running the following commands:

```powershell
# Begin Download Commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/restoreOracle/restoreOracle.ps1).content | Out-File restoreOracle.ps1; (Get-Content restoreOracle.ps1) | Set-Content restoreOracle.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/cloneOracle/cloneOracle.ps1).content | Out-File cloneOracle.ps1; (Get-Content cloneOracle.ps1) | Set-Content cloneOracle.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/destroyClone/destroyClone.ps1).content | Out-File destroyClone.ps1; (Get-Content destroyClone.ps1) | Set-Content destroyClone.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/backupNow/backupNow.ps1).content | Out-File backupNow.ps1; (Get-Content backupNow.ps1) | Set-Content backupNow.ps1
# End Download Commands
```

Please review the README for each:

* restoreOracle: <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/restoreOracle>
* cloneOracle: <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/cloneOracle>
* destroyClone: <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/destroyClone>
* backupNow: <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/backupNow>
