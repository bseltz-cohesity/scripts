# Run Multiple Scripts Concurrently using  PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a simple wrapper script that can run multiple PowerShell scripts concurrently in background jobs and monitor them to completion.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'threadWrapper'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Components

* [threadWrapper.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/threadWrapper/threadWrapper.ps1): the wrapper script

Edit the wrapper script accordingly. The example provided runs two instances of backupNow.ps1

```powershell
Write-Host "Starting backup1"
$cluster1 = 'cluster1.mydomain.net'
$username1 = 'myuser'
$job1 = 'my job 1'
$null = Start-Job -Name Job1 -ScriptBlock {c:\scripts\powershell\backupNow.ps1 -vip $using:cluster1 -username $using:username1 -jobName $using:job1 -interactive -sleepTimeSecs 10 -wait }

Write-Host "Starting backup2"
$cluster2 = 'cluster2.mydomain.net'
$username2 = 'admin'
$job2 = 'my job 2'
$null = Start-Job -Name Job2 -ScriptBlock {c:\scripts\powershell\backupNow.ps1 -vip $using:cluster2 -username $using:username2 -jobName $using:job2 -interactive -sleepTimeSecs 10 -wait }

$null = Wait-Job -Name Job1
$null = Wait-Job -Name Job2

Receive-Job -Name Job1
Receive-Job -Name Job2
```

Notice that each variable passed to the backupNow script, like `$cluster1` is passed as `$using:cluster1` this is required when passing parameters into the ScriptBlock of Start-Job.  

Once modified for your purpose, simply run the wrapper script.

```powershell
# example
./threadWrapper.ps1
# end example
```

`Note`: on PowerShell 5.1, if you are using this wrapper to run PowerShell scripts from [https://github.com/cohesity/community-automation-samples], you may need to get the latest cohesity-api.ps1 file located here: [https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api]
