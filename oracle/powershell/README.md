# Download the Cohesity Oracle PowerShell Scripts

There are four Oracle related scripts that are often useful to Oracle DBAs. They are:

* restoreOracle.ps1: restore an Oracle database for operational recovery or testing
* cloneOracle.ps1: clone an Oracle database for test/dev
* destroyClone.ps1: tear down an Oracle clone
* backupNow.ps1: perform an on demand backup

You can download these scripts onto your PC by opening a PowerShell session and running the following commands:

```powershell
# Begin Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/restoreOracle/restoreOracle.ps1).content | Out-File restoreOracle.ps1; (Get-Content restoreOracle.ps1) | Set-Content restoreOracle.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/cloneOracle/cloneOracle.ps1).content | Out-File cloneOracle.ps1; (Get-Content cloneOracle.ps1) | Set-Content cloneOracle.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/destroyClone/destroyClone.ps1).content | Out-File destroyClone.ps1; (Get-Content destroyClone.ps1) | Set-Content destroyClone.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/backupNow/backupNow.ps1).content | Out-File backupNow.ps1; (Get-Content backupNow.ps1) | Set-Content backupNow.ps1
# End Download Commands
```

Please review the README for each:

* restoreOracle: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle>
* cloneOracle: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/cloneOracle>
* destroyClone: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/destroyClone>
* backupNow: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/backupNow>
