# usage:
# ./protectionReport.ps1 -vip mycluster `
#                        -username myusername `
#                        -showApps `
#                        -smtpServer 192.168.1.95 `
#                        -sendTo me@mydomain.net `
#                        -sendFrom them@mydomain.net

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][switch]$useApiKey,                     # use API key for authentication
    [Parameter()][string]$password,                      # optional password
    [Parameter()][switch]$noPrompt,                      # do not prompt for password
    [Parameter()][string]$tenant,                        # org to impersonate
    [Parameter()][switch]$mcm,                           # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,               # MFA code
    [Parameter()][switch]$emailMfaCode,                  # email MFA code
    [Parameter()][string]$clusterName = $null,           # helios cluster to access
    [Parameter()][int]$daysBack = 7,  # number of days to include in report
    [Parameter()][array]$jobTypes,  # filter by type (SQL, Oracle, VMware, etc.)
    [Parameter()][array]$jobName,  # filter by job names (comma separated)
    [Parameter()][string]$jobList,  # filter by job names in text file (one per line) 
    [Parameter()][array]$objectNames, # filter by object names
    [Parameter()][switch]$failuresOnly,  # only show unsuccessful runs 
    [Parameter()][switch]$lastRunOnly,  # only show latest run
    [Parameter()][switch]$showObjects,  # show objects of jobs
    [Parameter()][switch]$showApps,  # show apps of objects
    [Parameter()][string]$smtpServer,  # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25,  # outbound smtp port
    [Parameter()][array]$sendTo,  # send to address
    [Parameter()][string]$sendFrom,  # send from address
    [Parameter()][string]$outPath,  # folder to write output file
    [Parameter()][switch]$skipLogBackups,
    [Parameter()][int]$numRuns = 1000
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

if($showApps){
    $showObjects = $True
}

if($outPath){
    if(! (Test-Path -PathType Container -Path $outPath)){
        $null = New-Item -ItemType Directory -Path $outPath -Force
    }
    if(! (Test-Path -PathType Container -Path $outPath)){
        Write-Host "OutPath $outPath not found!" -ForegroundColor Yellow
        exit
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$cluster = api get cluster

$title = "Cohesity Protection Report ($($cluster.name.ToUpper()))"

$global:message = '<html>
<head>
    <style>
        body {
            font-family: Helvetica, Arial, sans-serif;
            font-size: 12px;
            background-color: #f1f3f6;
            color: #444444;
            overflow: auto;
        }

        a {
            color: #0E4091;
            font-weight: 300;
            -webkit-text-decoration-color: #bbb; /* Safari */  
            text-decoration-color: #bbb;
        }

        a:visited {
            color: #0E4091;
            font-weight: 300;
        }

        a:hover {
            color: #000;
            font-weight: 300;
        }

        div {
            clear: both;
        }

        ul {
            margin: 2px; 2px; 2px; -5px;
        }

        li {
            margin-left: -25px;
            margin-bottom: 2px;
        }

        hr {
            border: 1px solid #F1F1F1;
            margin-left: 5px;
            margin-right: 5px;
        }

        #wrapper {
            background-color: #fff;
            width: fit-content;
            padding: 2px 6px 8px 6px;
            font-weight: 300;
            box-shadow: 1px 2px 4px #cccccc;
            border-radius: 4px;
        }

        .title {
            font-weight: bold;
        }

        .job {
            margin-left: 0px;
            font-weight: bold;
        }

        .snapshot {
            font-weight: normal;
            background-color: #FDFEFD;
            padding: 4px 6px 4px 6px;
            margin: 5px 7px 7px 15px;
            line-height: 1.5em;
            border-radius: 4px;
            box-shadow: 1px 2px 4px #CCCCCC;
        }

        .object {
            font-weight: 400;
            text-decoration: none;
            background-color: #FAFAFA;
            padding: 4px 6px 4px 6px;
            margin: 5px 7px 5px 20px;
        }

        .app {
            font-weight: 300;
            font-size: 11px;
            text-decoration: none;
            background-color: #FAFAFA;
            padding: 4px 6px 4px 6px;
            margin: 5px 7px 7px 25px;
        }

        .message {
            font-weight: 300;
            font-size: 10px;
            padding: 4px 6px 4px 6px;
            margin: 0px 7px 5px 15px;
        }

        .appmessage {
            font-weight: 300;
            font-size: 10px;
            padding: 4px 6px 4px 6px;
            margin: 0px 7px 5px 55px;
        }

        .date {
            display: inline-block;
            width: 18ch;
            color: #0E4091;
            text-align: right;
        }

        .info {
            font-weight: 300;
        }

        .runtype {
            font-weight: 300;
            color: #609;
            display: inline-block;
            width: 10ch;
            margin-left: 5px;
        }

        .remote {
            display: inline-block;
            width: 18ch;
            text-align: right;
        }

        .objectname {
            display: inline-block;
            width: 24ch;
            color: #222222;
        }

        .expiredate {
            display: inline-block;
            width: 9ch;
            color: #0E4091;
            text-align: center;
            margin-right: 2px;
        }

        .status {
            display: inline-block;
            width: 8ch;            
        }

        .Warning {
            font-weight: 300;
            color: #E5742A;
            display: inline-block;
            width: 8ch;
        }

        .Failure {
            font-weight: 300;
            color: #E2181A;
            display: inline-block;
            width: 8ch;
        }

        .Success {
            font-weight: 300;
            color: #008E00;
            display: inline-block;
            width: 8ch;
        }

        .Canceled {
            font-weight: 300;
            color: #FB9344;
            display: inline-block;
            width: 8ch;
        }

        .Pass {
            font-weight: 300;
            color: #008E00;
        }

        .Miss {
            font-weight: 300;
            color: #E2181A;
        }

    </style>
</head>

<body>
    <div id="wrapper">'

$global:message += '<p class="title">{0} Protection Report ({1})</p>' -f $cluster.name.ToUpper(), (Get-Date)

$dateString = get-date -UFormat '%Y-%m-%d'
$daysBackUsecs = (dateToUsecs (get-date -UFormat '%Y-%m-%d')) - ($daysBack * 86400000000)
$nowUsecs = dateToUsecs (get-date)

$jobs = api get "protectionJobs?includeLastRunAndStats=true" | Sort-Object -Property name | Where-Object {$_.isDeleted -ne $true -and $_.isPaused -ne $true -and $_.isActive -ne $false}
if($jobTypes){
    $jobs = $jobs | Where-Object {$_.environment.substring(1) -in $jobTypes -or $_.environment -in $jobTypes}
}

if($jobNames.Count -gt 0){
    $jobs = $jobs | Where-Object {$_.name -in $jobNames}
}

$maxLength = 0
$jobs.name | ForEach-Object{ if($_.Length -gt $maxLength){ $maxLength = $_.Length}}
$jobSpacer = ' ' * ($maxLength + 1)

function expiry($copyRun){
    if($copyRun.expiryTimeUsecs){
        if($copyRun.expiryTimeUsecs -lt $nowUsecs){
            return '- expired -'
        }else{
            return (usecsToDate $copyRun.expiryTimeUsecs).ToString('MM/dd/yyyy')
        }
    }else{
        return '- expired -'
    }
}

function displaySnapshot($run){
    $snapshotVisible = $false
    $link = "https://{0}/protection/job/{1}/run/{2}/{3}/protection" -f $vip, $job.id, $run.backupRun.jobRunId, $run.backupRun.stats.startTimeUsecs
    if($run.backupRun.slaViolated){
        $slaStatus = 'Miss'
        $global:showJob = $true
        $global:noFailures = $false
        $snapshotVisible = $true
    }else{
        $slaStatus = 'Pass'
    }
    $runType = $run.backupRun.runType.substring(1).replace('Regular', 'Incremental').Replace('System','Bare Metal')
    $localRun = $run.copyRun | Where-Object {$_.target.type -eq 'kLocal'}
    $expireTime = expiry $localRun
    $snapshotMessage = '<hr /><span class="date";><a href="{0}" target="_blank">{1}</a></span> <span class="runtype">{5}</span> <span class="status";><span class="{2}";>{2}</span></span> <span class="info";>Expires: <span class="expiredate">{3}</span> SLA: </span><span class="{4}";>{4}</span><br />' -f $link, 
                                                                                                                                                                                                                                                                                                                ((usecsToDate $run.backupRun.stats.startTimeUsecs).ToString('M/d/yyyy hh:mm tt')),
                                                                                                                                                                                                                                                                                                                $run.backupRun.status.subString(1),
                                                                                                                                                                                                                                                                                                                $expireTime,
                                                                                                                                                                                                                                                                                                                $slaStatus,
                                                                                                                                                                                                                                                                                                                $runType


    Write-Host ("{0}Local Snapshot: {1,20} ({2}) Expires: {3,20} SLA: {4}" -f $jobSpacer,
                                                                              (usecsToDate $run.backupRun.stats.startTimeUsecs),
                                                                              $run.backupRun.status.subString(1),
                                                                              $expireTime,
                                                                              $slaStatus)
    if($run.backupRun.status -ne 'kSuccess'){
        $snapshotVisible = $true
        $global:showJob = $true
        $global:noFailures = $false
    }
    if((! $failuresOnly) -or $snapshotVisible){
        return $snapshotMessage  
    }else{
        return $null
    }                                                           
}

function displayReplicas($run){
    $replicaMessage = ""
    $replicaVisible = $false
    $replicas = $run.copyRun | Where-Object {$_.target.type -eq 'kRemote'}
    foreach($replica in $replicas){
        $expireTime = expiry $replica
        $replicaMessage += '<span class="remote">{0}</span> <span class="runtype">Replica</span> <span class="status"><span class="{1}";>{1}</span></span> <span class="info">Expires: <span class="expiredate";>{2}</span></span><br />' -f $replica.target.replicationTarget.clusterName, 
                                                                                                                                                  $replica.status.subString(1),
                                                                                                                                                  $expireTime
        Write-Host ("{0}Replication --> {1,20} ({2}) Expires: {3,20}" -f $jobSpacer,
                                                                         $replica.target.replicationTarget.clusterName, 
                                                                         $replica.status.subString(1),
                                                                         $expireTime)
        if($replica.status -ne 'kSuccess'){
            $global:showJob = $true
            $global:noFailures = $false
            $replicaVisible = $true
        }
    }
    if((! $failuresOnly) -or $replicaVisible){
        return $replicaMessage
    }else{
        return $null
    }
    
}

function displayArchives($run){
    $archiveMessage = ""
    $archiveVisible = $false
    $archives = $run.copyRun | Where-Object {$_.target.type -eq 'kArchival'}
    foreach($archive in $archives){
        $expireTime = expiry $archive
        $archiveMessage += '<span class="remote">{0}</span> <span class="runtype">Archive</span> <span class="status"><span class="{1}";>{1}</span></span> <span class="info">Expires: <span class="expiredate";>{2}</span></span><br />' -f $archive.target.archivalTarget.vaultName, 
                                                                                                                                                  $archive.status.subString(1),
                                                                                                                                                  $expireTime

        Write-Host ("{0}    Archive --> {1,20} ({2}) Expires: {3,20}" -f $jobSpacer,
                                                                         $archive.target.archivalTarget.vaultName, 
                                                                         $archive.status.subString(1),
                                                                         $expireTime)
        if($archive.status -ne 'kSuccess'){
            $global:showJob = $true
            $global:noFailures = $false
            $replicaVisible = $true
        }   
    }
    if((! $failuresOnly) -or $archiveVisible){
        return $archiveMessage
    }else{
        return $null
    }
    
}

function displayObject($task){
    
    if($objectNames.Length -eq 0 -or $task.base.sources[0].source.displayName -in $objectNames){
        $global:inScope = $true
        $msg = ''
        $objectVisible = $false
        if($task.base.error){
            $msg = $task.base.error[0].errorMsg
            $msgHTML = '<ul><li>{0}</li></ul>' -f $task.base.error[0].errorMsg
            $objectsVisible = $objectVisible = $true
        }
        if($task.base.warnings){
            $msg = $task.base.warnings[0].errorMsg
            $msgHTML = '<ul><li>{0}</li></ul>' -f ($task.base.warnings.errorMsg -join "</li><li>")
            $objectsVisible = $objectVisible = $true
        }
        if($objectsVisible){
            $global:showJob = $true
            $global:noFailures = $false
        }
        if(!($failuresOnly -and $task.base.publicStatus -eq 'kSuccess')){
            # Write-Host "*** $($task.base.sources[0].source.displayName)"
            $taskMessage = '<span class="info"> <span class="{1}">{1}</span></span> <span class="objectname">{0}</span><br />' -f $task.base.sources[0].source.displayName, $task.base.publicStatus.subString(1)
            if($msg -ne ''){
                $taskMessage += '<div class="message">{0}</div>' -f $msgHTML
            }
            write-host ("{0} {1,35} ({2}) {3}" -f $jobSpacer,
            $task.base.sources[0].source.displayName,
            $task.base.publicStatus.subString(1),
            $msg)
            if($showApps){
                $taskMessage += displayApps $task
            }
        }
        if($task.base.sources[0].source.displayName -in $objectNames){
            $global:showJob = $true
        }
        # Write-Host "*** $($global:showJob)"
        return $taskMessage
    }else{
        # $global:showJob = $false
        return $null
    }
}

function displayObjects($run){
    $taskMessages = @()
    $objectsVisible = $false
    if(! $run.backupRun.snapshotsDeleted){
        $thisRun = api get "/backupjobruns?id=$($job.id)&exactMatchStartTimeUsecs=$($run.backupRun.stats.startTimeUsecs)"
        $objectMessage = '<div class="object">'
        foreach($task in $thisRun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks | Sort-Object -Property {$_.base.sources[0].source.displayName}){
            $taskMessage = displayObject $task
            if($taskMessage){
                $objectsVisible = $true
                if(!($taskMessage -in $taskMessages)){
                    $objectMessage += $taskMessage
                    $taskMessages += $taskMessage
                }
                $global:showJob = $true
            }
        }
        $objectMessage += '</div>'
    }else{
        $objectMessage += '<br />'
    }
    if($objectsVisible){
        return $objectMessage
    }else{
        return $null
    }
}

function displayApp($app){
    $msgHTML = $null
    if($app.publicStatus -eq 'kSuccess'){
        $status = '(Success)'
        $statusHTML = 'Success'
    }
    if($app.error){
        $status = '(Failure) ' + $app.error[0].errorMsg
        $statusHTML = 'Failure'
        $msgHTML = '<ul><li>{0}</li></ul>' -f $app.error[0].errorMsg
        $global:noFailures = $false
    }
    if($app.warnings){
        $status = '(Warning) ' + $app.warnings[0].errorMsg
        $statusHTML = 'Warning'
        $msgHTML = '<ul><li>{0}</li></ul>' -f ($app.warnings.errorMsg -join "</li><li>")
        $global:noFailures = $false
    }
    if(!($failuresOnly -and $app.publicStatus -eq 'kSuccess')){
        $appMessage = '<span class="info"> <span class="{1}">{1}</span></span> <span class="objectname">{0}</span><br />' -f $app.appEntity.displayName, $statusHTML
        if($msgHTML){
            $appMessage += '<div class="appmessage">{0}</div>' -f $msgHTML
        }
        write-host ("{0} {1,45} {2}" -f $jobSpacer, $app.appEntity.displayName,$status)
        $global:showJob = $true
    }
    return $appMessage
}

function displayApps($task){
    $appsVisible = $false
    if($task.PSObject.Properties['appEntityStateVec']){
        $appsMessage = '<div class="app">'
        foreach($app in $task.appEntityStateVec | Sort-Object -Property {$_.appEntity.displayName}){
            $appsMessage += displayApp $app
            if($appsMessage){
                $appsVisible = $true
            }
        }
        $appsMessage += '</div>'
    }
    if($appsVisible){
        return $appsMessage
    }else{
        return $null
    }
}

$global:noFailures = $True

foreach($job in $jobs){
    $global:inScope = $True

    if($failuresOnly){
        $global:showJob = $false
    }else{
        $global:showJob = $true
    }

    if($objectNames.Length -gt 0){
        $showObjects = $True
        $global:showJob = $false
        $global:inScope = $false
    }

    if($job.lastRun.backupRun.slaViolated){
        $slaStatus = 'Miss'
    }else{
        $slaStatus = 'Pass'
    }

    if($job.lastRun){
        $endUsecs = $nowUsecs
        $moreRuns = $True
        $jobMessage = '<br /><div class="job"><span>{0}</span><span class="info"> ({1})</span></div><div class="snapshot">' -f $job.name.ToUpper(), $job.environment.substring(1)
            "`n{0,$maxLength} ({1})`n" -f $job.name, $job.environment.subString(1)
        while($moreRuns -eq $True){
            if($lastRunOnly){
                if($skipLogBackups){
                    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&excludeTasks=true&runTypes=kRegular&runTypes=kFull"
                }else{
                    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&excludeTasks=true"
                }
            }else{
                if($skipLogBackups){
                    $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$daysBackUsecs&endTimeUsecs=$endUsecs&numRuns=$numRuns&excludeTasks=true&runTypes=kRegular&runTypes=kFull"
                }else{
                    $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$daysBackUsecs&endTimeUsecs=$endUsecs&numRuns=$numRuns&excludeTasks=true"
                }   
            }
    
            foreach($run in $runs){
                $jobMessage += displaySnapshot $run
                $jobMessage += displayReplicas $run
                $jobMessage += displayArchives $run
                if($showObjects){
                    $jobMessage += displayObjects $run
                }
                $endUsecs = $run.backupRun.stats.endTimeUsecs - 1
            }
            if(!$runs -or $runs.Count -lt $numRuns){
                $moreRuns = $false
            }
            # Write-Host "$($runs.Count)"
        }
        $jobMessage += '</div>'
        if($global:showJob -and $global:inScope){
            $global:message += $jobMessage
        }
    }
}

if($global:noFailures){
    $global:message += '<p class="job" style="color: #008E00; font-weight: 400;">No New Failures or Warnings Detected</p>'
    Write-Host "No failures or warnings detected" -ForegroundColor Green
}

$global:message += '</div></body></html>'
$fileName = "$($cluster.name.ToUpper())-protectionReport-$dateString.html"
if($outPath){
    $fileName = Join-Path -Path $outPath -ChildPath $fileName
}
$global:message | out-file -FilePath $fileName

if($smtpServer -and $sendTo -and $sendFrom){
    write-host "`nsending report to $([string]::Join(", ", $sendTo))"
    # send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $message -Attachments $fileName -WarningAction SilentlyContinue
    }
}
