# Example Cohesity Agent Pre/Post Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is an example of how to run API scripts as a Cohesity Agent Pre/Post script.

## Components

* test.cmd: Batch file (Pre/Post Script)
* backupNowAndCopy.ps1: example PowerShell script
* cohesity-api-user-scripts.ps1: the Cohesity REST API helper module (variant for LocalSystem)

Place all files in c:\program files\Cohesity\user_scripts\ 

Modify the cmd file to run the powershell script with the arguments desired. For example

```cmd
powershell.exe "& 'c:\program files\cohesity\user_scripts\backupNowAndCopy.ps1' -vip mycluster -username admin -jobName 'File-Based Backup' -replicateTo CohesityVE -keepReplicaFor 5"
```

This command launches PowerShell and executes the backupNowAndCopy.ps1 with argumentd to start the protectionJob 'File-Based Backup'.

To test that the script will work, run the script interactively from a Windows command prompt on the Windows server.

```powershell
C:\Users\myuser>cd "\Program Files\Cohesity\user_scripts"

C:\Program Files\Cohesity\user_scripts>test.cmd

C:\Program Files\Cohesity\user_scripts>powershell.exe "& 'c:\program files\cohesity\user_scripts\backupNowAndCopy.ps1' -vip mycluster -username admin -jobName 'File-Based Backup' -replicateTo CohesityVE -keepReplicaFor 5"
enter password: *****
Connected!
Running File-Based Backup...
```

Once the password has been entered, it will be stored for later use. Also, the 'File-Based Backup' job should have started on mycluster.

Now we can enter 'test.cmd' as the post script in another protection job. Once that's set, the first job will run, then kick off the second job, in waterfall fashion. 


## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/user_scripts/backupNowAndCopy.ps1).content | Out-File backupNowAndCopy.ps1; (Get-Content backupNowAndCopy.ps1) | Set-Content backupNowAndCopy.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/user_scripts/cohesity-api-user-scripts.ps1).content | Out-File cohesity-api-user-scripts.ps1; (Get-Content cohesity-api-user-scripts.ps1) | Set-Content cohesity-api-user-scripts.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/user_scripts/test.cmd).content | Out-File test.cmd; (Get-Content test.cmd) | Set-Content test.cmd
```
