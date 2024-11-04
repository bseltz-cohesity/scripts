### usage: 
# ./jobFailures.ps1 -vip mycluster `
#                   -username myuser `
#                   -domain mydomain.net `
#                   -smtpServer mySMTPserver `
#                   -sendTo me@mydomain.net `
#                   -sendFrom helios@mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$consoleWidth = $Host.UI.RawUI.WindowSize.Width

$cluster = api get cluster

$title = "Cohesity Failure Report ($($cluster.name.ToUpper()))"
$message = '<html>
<head>
    <style>
        body {
            font-family: Helvetica, Arial, sans-serif;
            font-size: 12px;
            background-color: #f1f3f6;
            color: #444444;
            overflow: auto;
        }

        div {
            clear: both;
        }

        ul {
            displa-block;
            margin: 2px; 2px; 2px; -5px;
        }

        li {
            margin-left: -25px;
            margin-bottom: 2px;
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

        .jobname {
            margin-left: 0px;
            font-weight: normal;
            color: #000;
        }

        .info {
            font-weight: 300;
            color: #000;
        }

        .Warning {
            font-weight: normal;
            color: #E5742A;
        }

        .Failure {
            font-weight: normal;
            color: #E2181A;
        }

        .object {
            margin: 4px 0px 2px 20px;
            font-weight: normal;
            color: #000;
            text-decoration: none;
        }

        .message {
            font-weight: 300;
            font-size: 11px;
            background-color: #f1f3f6;
            padding: 4px 6px 4px 6px;
            margin: 5px 7px 7px 15px;
            line-height: 1.5em;
            border-radius: 4px;
            box-shadow: 1px 2px 4px #cccccc;
        }
    </style>
</head>

<body>
    <div id="wrapper">'

$message += '<p class="title">{0} Job Failure Report ({1})</p>' -f $cluster.name.ToUpper(), (Get-Date)
$failureCount = 0

$jobs = api get protectionJobs | Sort-Object -Property name
foreach($job in $jobs){
    if($job.isDeleted -ne $true -and $job.isPaused -ne $true -and $job.isActive -ne $false){
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=2" | 
            where-object {$_.backupRun.status -eq 'kFailure' -or $_.backupRun.PSObject.Properties['Warnings']}
        if($runs.count -gt 0){
            $run = $runs[0]
            $failureCount += 1
            if($run.backupRun.status -eq 'kFailure'){
                $msgType = 'Failure'
            }else{
                $msgType = 'Warning'
            }
            
            $link = "https://{0}/protection/job/{1}/run/{2}/{3}/protection" -f $vip, $job.id, $run.backupRun.jobRunId, $run.backupRun.stats.startTimeUsecs
            "{0} ({1}) {2}" -f $job.name.ToUpper(), $job.environment.substring(1), (usecsToDate $run.backupRun.stats.startTimeUsecs)
            if($failureCount -gt 1){
                $message += '<br/>'
            }
            $message += '<div class="jobname"><span>{0}</span><span class="info"> ({1}) <a href="{2}" target="_blank">{3}</a></span></div>' -f $job.name.ToUpper(), $job.environment.substring(1), $link, (usecsToDate $run.backupRun.stats.startTimeUsecs)
            $message += '<div class="object">'        
            foreach($source in $run.backupRun.sourceBackupStatus){
                if($source.status -eq 'kFailure' -or $source.PSObject.Properties['warnings']){
                    if($source.status -eq 'kFailure'){
                        $msg = $source.error
                        $msgHTML = "<ul><li>{0}</li></ul>" -f $source.error
                        $msgType = 'Failure'
                    }else{
                        $msg = $source.warnings[0]
                        $msgHTML = "<ul><li>{0}</li></ul>" -f ($source.warnings -join "</li><li>")
                        # $msgHTML
                        $msgType = 'Warning'
                    }
                    $objectReport = "    {0} ({1}): {2}" -f $source.source.name.ToUpper(), $msgType, $msg
        
                    if($objectReport.ToString().length -gt ($consoleWidth-5)){
                        $objectReport = "$($objectReport.substring(0,($consoleWidth-6)))..."
                    }
                    $objectReport
                    $message += '<span>{0}</span><span class="info"> (<span class="{1}">{2}</span>)</span><div class="message">{3}</div>' -f $source.source.name.ToUpper(), $msgType, $msgType, $msgHTML
                }
            }
            $message += '</div>'
        }  
    }
}   

$message += '</div></body></html>'
$message | out-file -FilePath "$($cluster.name.ToUpper())-jobFailures.html"

if($failureCount -and $smtpServer -and $sendTo -and $sendFrom){
    write-host "`nsending report to $([string]::Join(", ", $sendTo))"
    # send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $message -WarningAction SilentlyContinue
    }
}