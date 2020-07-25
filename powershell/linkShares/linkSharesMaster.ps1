# usage: .\linkSharesMaster.ps1 -linuxUser myuser `
#                               -linuxHost myhost `
#                               -linuxPath /home/myuser/mydir `
#                               -statusFile \\mylinkmaster\myshare\linkSharesStatus.json

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$linuxUser,
    [Parameter(Mandatory = $True)][string]$linuxHost,
    [Parameter(Mandatory = $True)][string]$linuxPath,
    [Parameter(Mandatory = $True)][string]$statusFile,
    [Parameter()][int64]$lockTimeOut = 10,
    [Parameter()][string]$smtpServer, # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, # outbound smtp port
    [Parameter()][array]$sendTo, # send to address
    [Parameter()][string]$sendFrom # send from address
)

# create any missing links
write-host "Searching for new workspaces..."
$workspaces = (ssh -qt "$linuxUser@$linuxHost" 'ls -1 '$linuxPath)
$shows = $workspaces | Group-Object -Property {$_.split('_')[0]}
$thisComputer = $Env:Computername

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

# wait for and aqcuire lock on status file
$waitFor = $lockTimeOut + (Get-Random -Maximum 10)
$waitedFor = 0
$status = 'Running'
"waiting for exclusive config file access..."
while($status -ne 'Ready'){
    Start-Sleep -Seconds 1
    $config = Get-Content -Path $statusFile | ConvertFrom-Json
    $status = $config.status
    $waitedFor += 1
    if($waitedFor -gt $waitFor){
        # release lock ---------------------------------------
        sendAlert "Status file was locked by $($config.lockedBy) - resetting...`nPlease check $($config.lockedBy) it might be stuck"
        $config.lockedBy = ''
        $config.status = 'Ready'
        $config | ConvertTo-Json -Depth 99 | Set-Content -Path $statusFile
        Start-Sleep -Seconds (5 + (Get-Random -Maximum 10))
        $waitedFor = 0
    }
}
"acquired exclusive lock"
$config.status = 'Running'
$config.lockedBy = $thisComputer
$config | ConvertTo-Json -Depth 99 | Set-Content -Path $statusFile

# lock acquired - do stuff to the file ---------------

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
        "adding $($show.Name) to $($thisProxy.name) ($($thisProxy.shows.count))"
        $thisProxy.shows += $show.Name
    }
}

# release lock ---------------------------------------
$config.lockedBy = ''
$config.status = 'Ready'
$config | ConvertTo-Json -Depth 99 | Set-Content -Path $statusFile
"Lock released"
