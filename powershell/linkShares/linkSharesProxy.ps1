# usage: .\linkSharesProxy.ps1 -vip mycluster `
#                              -username myusername `
#                              -domain mydomain.net `
#                              -jobName 'my job name' `
#                              -nas mynas `
#                              -localDirectory C:\Cohesity\ `
#                              -statusFile \\mylinkmaster\myshare\linkSharesStatus.json

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$nas,  # name of nas target
    [Parameter(Mandatory = $True)][string]$localDirectory,  # local path where links will be created
    [Parameter(Mandatory = $True)][string]$statusFile,  # unc path to central json file
    [Parameter()][int64]$lockTimeOut = 10,
    [Parameter(Mandatory = $True)][string]$jobName,  # name of cohesity protection job
    [Parameter()][string]$smtpServer, # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, # outbound smtp port
    [Parameter()][array]$sendTo, # send to address
    [Parameter()][string]$sendFrom # send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

# get physical protection sources
$thisComputer = $Env:Computername
$sources = api get protectionSources?environment=kPhysical

$source = $sources.nodes | Where-Object {$_.protectionSource.name -match $thisComputer}
if(!$source){
    write-warning "$thisComputer not registered in Cohesity!"
    exit
}

$localLinks = (Get-Item $localDirectory) | Get-ChildItem

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

$config = Get-Content -Path $statusFile | ConvertFrom-Json

# register this proxy
if(! ($config.proxies | Where-Object name -eq $thisComputer)){
    "Registering as new proxy..."
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
    $config.proxies += @{'name'= $thisComputer; 'shows'= @()}
    # release lock ---------------------------------------
    $config.lockedBy = ''
    $config.status = 'Ready'
    $config | ConvertTo-Json -Depth 99 | Set-Content -Path $statusFile
}
$thisProxy = $config.proxies | Where-Object name -eq $thisComputer

# report existing shows
foreach($localLink in $localLinks.Name){
    $showname = $localLink.split('_')[0]
    if(! ($showname -in $thisProxy.shows)){
        $thisProxy.shows += $showname
    }
}

# check for new links to create
$newLinksFound = $false
$myShows = $thisProxy.shows
$workSpaces = $config.workspaces
foreach($workspace in $workSpaces){
    $show = $workspace.split('_')[0]
    if($show -in $myShows){
        if(! ($workspace -in $localLinks.Name)){
            write-host "adding $workspace"
            $null = new-item -ItemType SymbolicLink -Path $localDirectory -name $workspace -Value \\$nas\$workspace
            $newLinksFound = $True
        }
    }
}

if($newLinksFound){
    # refresh localLinks
    $localLinks = (Get-Item $localDirectory) | Get-ChildItem

    # add new links to inclusions
    foreach($sourceSpecialParameter in $job.sourceSpecialParameters){
        if($sourceSpecialParameter.sourceId = $source.protectionSource.id){
            foreach($localLink in $localLinks){
                $linkPath = '/' + $localLink.fullName.replace(':','').replace('\','/')
                if($linkPath -notin $sourceSpecialParameter.physicalSpecialParameters.filePaths.backupFilePath){
                    write-host "adding new link $($localLink.fullName) to protection job..."
                    $sourceSpecialParameter.physicalSpecialParameters.filePaths += @{'backupFilePath' = $linkPath; 'skipNestedVolumes' = $false }
                }
            }
            $sourceSpecialParameter.physicalSpecialParameters.filePaths = $sourceSpecialParameter.physicalSpecialParameters.filePaths | Sort-Object -Property {$_.backupFilePath}
        }
    }

    # update job
    $null = api put "protectionJobs/$($job.id)" $job
}else{
    Write-Host "No new links found"
}
