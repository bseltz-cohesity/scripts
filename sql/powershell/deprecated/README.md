# Download the Cohesity SQL PowerShell Scripts

There are four SQL related scripts that are often useful to SQL DBAs. They are:

* restoreSQL.ps1: restore a SQL database for operational recovery or testing
* cloneSQL.ps1: clone a SQL database for test/dev
* destroyClone.ps1: tear down a SQL clone
* backupNow.ps1: perform an on demand backup

You can download these scripts onto your PC by opening a PowerShell session and running the following commands:

```powershell
# Begin Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/restoreSQL/restoreSQL.ps1).content | Out-File restoreSQL.ps1; (Get-Content restoreSQL.ps1) | Set-Content restoreSQL.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/cloneSQL/cloneSQL.ps1).content | Out-File cloneSQL.ps1; (Get-Content cloneSQL.ps1) | Set-Content cloneSQL.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/destroyClone/destroyClone.ps1).content | Out-File destroyClone.ps1; (Get-Content destroyClone.ps1) | Set-Content destroyClone.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/backupNow/backupNow.ps1).content | Out-File backupNow.ps1; (Get-Content backupNow.ps1) | Set-Content backupNow.ps1
# End Download Commands
```
