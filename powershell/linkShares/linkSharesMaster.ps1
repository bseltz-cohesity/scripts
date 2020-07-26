# usage: .\linkSharesMaster.ps1 -linuxUser myuser `
#                               -linuxHost myhost `
#                               -linuxPath /home/myuser/mydir `
#                               -statusFolder \\mylinkmaster\myshare

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$linuxUser,
    [Parameter(Mandatory = $True)][string]$linuxHost,
    [Parameter(Mandatory = $True)][string]$linuxPath,
    [Parameter(Mandatory = $True)][string]$statusFolder,
    [Parameter()][string]$smtpServer, # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, # outbound smtp port
    [Parameter()][array]$sendTo, # send to address
    [Parameter()][string]$sendFrom, # send from address
    [Parameter()][Int64]$maxCheckinHours = 25
)

$logFile = Join-Path -Path $statusFolder -ChildPath "master.log"
$statusFile = Join-Path -Path $statusFolder -ChildPath "linkSharesStatus.json"
$config = Get-Content -Path $statusFile | ConvertFrom-Json
"Check in at $(Get-Date)" | Out-File -FilePath $logFile

# backup status file
$backupFile = Join-Path -Path $statusFolder -ChildPath "linkSharesStatus-backup$((get-date).DayOfYear % 3).json"
$config | ConvertTo-Json -Depth 99 | Set-Content -Path $backupFile

# create any missing links
"Searching for new workspaces..." | Tee-Object -FilePath $logFile -Append
$workspaces = (ssh -qt "$linuxUser@$linuxHost" 'ls -1 '$linuxPath)
$shows = $workspaces | Group-Object -Property {$_.split('_')[0]}

function sendAlert($msg){
    Write-Host $msg -ForegroundColor Yellow
    $title = 'linkShares alert'
    if($smtpServer -and $sendTo -and $sendFrom){
        write-host "sending alert to $([string]::Join(", ", $sendTo))"
        # send email report
        foreach($toaddr in $sendTo){
            Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -Body $msg -WarningAction SilentlyContinue
        }
    }
}

foreach($show in $shows){

    # add show to show list
    if(! ($show.Name -in $config.shows)){
        $config.shows += $show.Name
    }

    # add workspace to workspaces
    foreach($workspace in $show.Group){
        if(! ($workspace -in $config.workspaces)){
            $config.workspaces += $workspace
        }
    }

    # see if a proxy already has this show
    if(! ($config.proxies | Where-Object {$show.Name -in $_.shows})){

        # find least used proxy
        $leastUsedProxy = ''
        $leastShowCount = 999999
        foreach($proxy in $config.proxies){
            if($proxy.shows.count -lt $leastShowCount){
                $leastUsedProxy = $proxy.name
                $leastShowCount = $proxy.shows.count
            }
        }

        # add show to least used proxy
        $thisProxy = $config.proxies | Where-Object name -eq $leastUsedProxy
        "adding $($show.Name) to $($thisProxy.name) ($($thisProxy.shows.count))" | Tee-Object -FilePath $logFile -Append
        $thisProxy.shows += $show.Name
    }
}

$config | ConvertTo-Json -Depth 99 | Set-Content -Path $statusFile

# check for dead proxies
$alert = ""
foreach($proxy in $config.proxies){
    $logPath = Join-Path -Path $statusFolder -ChildPath "$($proxy.name).log"
    if(Test-Path -Path $logPath){
        $proxyLog = Get-Item -Path $logPath
        $hours = ((Get-Date) - $proxyLog.LastWriteTime).TotalHours
        if($hours -gt $maxCheckinHours){
            $alert += "Proxy $($proxy.name) is late checking in`n"
        }
    }else{
        $alert += "Proxy $($proxy.name) has not checked in`n"
    }
}
if($alert -ne ""){
    "$alert" | Out-File -FilePath $logFile -Append
    sendAlert $alert
}
"Completed at $(get-date)" | Tee-Object -FilePath $logFile -Append
