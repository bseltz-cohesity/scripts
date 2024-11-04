# Clone a SQL Database using a SQL Agent Job

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This demonstrates how to clone a SQL database using a SQL Agent job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneSQL'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'destroyClone'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/sqlAgentJob-cloneDB/createCloneSQLAgentJob.sql").content | Out-File createCloneSQLAgentJob.sql; (Get-Content createCloneSQLAgentJob.sql) | Set-Content createCloneSQLAgentJob.sql
# End Download Commands
```

## Components

* [cloneSQL.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/sqlAgentJob-cloneDB/cloneSQL.ps1): clone a SQL database
* [destroyClone.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/sqlAgentJob-cloneDB/destroyClone.ps1): tear down an existing clone
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/sqlAgentJob-cloneDB/cohesity-api.ps1): the Cohesity REST API helper module
* [createCloneSQLAgentJob.sql](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/sqlAgentJob-cloneDB/createCloneSQLAgentJob.sql): T-SQL to create the SQL Agent Job

## Creating the SQL Agent Job

Open SSMS and open the createCloneSQLAgentJob.sql in a query window, review it and execute it. It should create a new SQL Agent job called 'Clone DB'

The job has two steps, 1) tear down an existing clone (if any) and 2) create a new clone. Edit the steps and adjust the commands to suite your environment.

## Authentication to Cohesity

The username and domain parameters in the scripts (as called in the SQL Agent job steps) must have the correct access defined in Cohesity. No privileged access is required on the SQL server where the job is executed.

To make these scripts run unattended, we must store the cohesity user's password. This will be stored as an encrypted secure string accessible only by the Windows account that the SQL Agent service runs as.

To get the password stored, remote desktop into the SQL server as the SQL Agent service user. Alternatively, you can shift-right-click the PowerShell icon and "run as a different user", and use the SQL Agent servicee user. Then simply run one of the PowerShell scripts in the SQL agent job, from the PowerShell command line. You will be prompted to enter the password, after which the password will be stored for future use. Then, the SQL agent job will be able to run without being prompted for a password.

## Additional Command Line Parameters

Both of the PowerShell scripts included in this package have various command line parameters. You can find them here:

* [cloneSQL.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/sqlAgentJob-cloneDB/cloneSQL.ps1): <https://github.com/cohesity/community-automation-samples/tree/main/sql/cloneSQL>
* [destroyClone.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/sqlAgentJob-cloneDB/destroyClone.ps1): <https://github.com/cohesity/community-automation-samples/tree/main/sql/destroyClone>
