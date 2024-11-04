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
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][int]$daysBack = 7,  # number of days to include in report
    [Parameter()][switch]$lastRunOnly,  # only show latest run
    [Parameter()][switch]$showObjects,  # show objects of jobs
    [Parameter()][switch]$showApps,  # show apps of objects
    [Parameter()][string]$smtpServer,  # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25,  # outbound smtp port
    [Parameter()][array]$sendTo,  # send to address
    [Parameter()][string]$sendFrom,  # send from address
    [Parameter()][string]$outPath  # folder to write output file
)

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
apiauth -vip $vip -username $username -domain $domain -helios

foreach($cluster in heliosClusters){

    heliosCluster $cluster

    $clusterPartitions = api get clusterPartitions
    $vip = $clusterPartitions.hostName
    $title = "Cohesity Protection Report ($($cluster.name.ToUpper()))"
    $title

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
    
    $jobs = api get "protectionJobs?includeLastRunAndStats=true" | Sort-Object -Property name
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
        $link = "https://{0}/protection/job/{1}/run/{2}/{3}/protection" -f $vip, $job.id, $run.backupRun.jobRunId, $run.backupRun.stats.startTimeUsecs
        if($run.backupRun.slaViolated){
            $slaStatus = 'Miss'
        }else{
            $slaStatus = 'Pass'
        }
        $runType = $run.backupRun.runType.substring(1).replace('Regular', 'Incremental').Replace('System','Bare Metal')
        $localRun = $run.copyRun | Where-Object {$_.target.type -eq 'kLocal'}
        $expireTime = expiry $localRun
        $global:message += '<hr /><span class="date";><a href="{0}" target="_blank">{1}</a></span> <span class="runtype">{5}</span> <span class="status";><span class="{2}";>{2}</span></span> <span class="info";>Expires: <span class="expiredate">{3}</span> SLA: </span><span class="{4}";>{4}</span><br />' -f $link, 
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
    }
    
    function displayReplicas($run){
        $replicas = $run.copyRun | Where-Object {$_.target.type -eq 'kRemote'}
        foreach($replica in $replicas){
            $expireTime = expiry $replica
            $global:message += '<span class="remote">{0}</span> <span class="runtype">Replica</span> <span class="status"><span class="{1}";>{1}</span></span> <span class="info">Expires: <span class="expiredate";>{2}</span></span><br />' -f $replica.target.replicationTarget.clusterName, 
                                                                                                                                                      $replica.status.subString(1),
                                                                                                                                                      $expireTime
            Write-Host ("{0}Replication --> {1,20} ({2}) Expires: {3,20}" -f $jobSpacer,
                                                                             $replica.target.replicationTarget.clusterName, 
                                                                             $replica.status.subString(1),
                                                                             $expireTime)
        }
    }
    
    function displayArchives($run){
        $archives = $run.copyRun | Where-Object {$_.target.type -eq 'kArchival'}
        foreach($archive in $archives){
            $expireTime = expiry $archive
            $global:message += '<span class="remote">{0}</span> <span class="runtype">Archive</span> <span class="status"><span class="{1}";>{1}</span></span> <span class="info">Expires: <span class="expiredate";>{2}</span></span><br />' -f $archive.target.archivalTarget.vaultName, 
                                                                                                                                                      $archive.status.subString(1),
                                                                                                                                                      $expireTime
    
            Write-Host ("{0}    Archive --> {1,20} ({2}) Expires: {3,20}" -f $jobSpacer,
                                                                             $archive.target.archivalTarget.vaultName, 
                                                                             $archive.status.subString(1),
                                                                             $expireTime)
        }
    }
    
    function displayObjects($run){
        if(! $run.backupRun.snapshotsDeleted){
            $thisRun = api get "/backupjobruns?id=$($job.id)&exactMatchStartTimeUsecs=$($run.backupRun.stats.startTimeUsecs)"
            $global:message += '<div class="object">'
            foreach($task in $thisRun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks | Sort-Object -Property {$_.base.sources[0].source.displayName}){
                $msg = ''
                if($task.base.error){
                    $msg = $task.base.error[0].errorMsg
                    $msgHTML = '<ul><li>{0}</li></ul>' -f $task.base.error[0].errorMsg
                }
                if($task.base.warnings){
                    $msg = $task.base.warnings[0].errorMsg
                    $msgHTML = '<ul><li>{0}</li></ul>' -f ($task.base.warnings.errorMsg -join "</li><li>")
                }
                $global:message += '<span class="info"> <span class="{1}">{1}</span></span> <span class="objectname">{0}</span><br />' -f $task.base.sources[0].source.displayName, 
                                                                                                                                                $task.base.publicStatus.subString(1)
                if($msg -ne ''){
                    $global:message += '<div class="message">{0}</div>' -f $msgHTML
                }
                "{0} {1,35} ({2}) {3}" -f $jobSpacer,
                                                $task.base.sources[0].source.displayName,
                                                $task.base.publicStatus.subString(1),
                                                $msg
                if($showApps){
                    displayApps $task
                }
            }
            $global:message += '</div>'
        }else{
            $global:message += '<br />'
        }
    }
    
    function displayApps($task){
        if($task.PSObject.Properties['appEntityStateVec']){
            $global:message += '<div class="app">'
            foreach($app in $task.appEntityStateVec | Sort-Object -Property {$_.appEntity.displayName}){
                $msgHTML = $null
                if($app.publicStatus -eq 'kSuccess'){
                    $status = '(Success)'
                    $statusHTML = 'Success'
                }
                if($app.error){
                    $status = '(Failure) ' + $app.error[0].errorMsg
                    $statusHTML = 'Failure'
                    $msgHTML = '<ul><li>{0}</li></ul>' -f $app.error[0].errorMsg
                }
                if($app.warnings){
                    $status = '(Warning) ' + $app.warnings[0].errorMsg
                    $statusHTML = 'Warning'
                    $msgHTML = '<ul><li>{0}</li></ul>' -f ($app.warnings.errorMsg -join "</li><li>")
                }
                $global:message += '<span class="info"> <span class="{1}">{1}</span></span> <span class="objectname">{0}</span><br />' -f $app.appEntity.displayName,
                                                                                                                                          $statusHTML
                if($msgHTML){
                    $global:message += '<div class="appmessage">{0}</div>' -f $msgHTML
                }
                "{0} {1,45} {2}" -f $jobSpacer,
                                      $app.appEntity.displayName,
                                      $status
            }
            $global:message += '</div>'
        }
    }
    
    foreach($job in $jobs){
        if($job.lastRun.backupRun.slaViolated){
            $slaStatus = 'Miss'
        }else{
            $slaStatus = 'Pass'
        }
        if($job.isDeleted -ne $true -and $job.isPaused -ne $true -and $job.isActive -ne $false){
            # lastest run summary
            $global:message += '<br /><div class="job"><span>{0}</span><span class="info"> ({1})</span></div>' -f $job.name.ToUpper(), $job.environment.substring(1)
            "`n{0,$maxLength} ({1})`n" -f $job.name, $job.environment.subString(1)
            $global:message += '<div class="snapshot">'
            displaySnapshot $job.lastRun
            displayReplicas $job.lastRun
            displayArchives $job.lastRun
            if($showObjects){
                displayObjects $job.lastRun
            }
            if(! $lastRunOnly){
                # get runs
                $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$daysBackUsecs&excludeTasks=true"
                foreach($run in $runs | Where-Object {$_.backupRun.stats.startTimeUsecs -ne $job.lastRun.backupRun.stats.startTimeUsecs}){
                    displaySnapshot $run
                    displayReplicas $run
                    displayArchives $run
                    if($showObjects){
                        displayObjects $run
                    }
                }
            }
            $global:message += '</div>'
        }
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
}
