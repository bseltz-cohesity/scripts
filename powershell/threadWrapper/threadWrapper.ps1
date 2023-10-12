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
