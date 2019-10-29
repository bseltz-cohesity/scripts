### usage: ./strikeReport.ps1 -vip mycluster -username myusername -domain mydomain.net -sendTo myuser@mydomain.net, anotheruser@mydomain.net -smtpServer 192.168.1.95 -sendFrom backupreport@mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter(Mandatory = $True)][array]$sendTo, #send to address
    [Parameter(Mandatory = $True)][string]$sendFrom #send from address
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$environments = @('kUnknown', 'kVMware' , 'kHyperV' , 'kSQL' , 'kView' , 'kPuppeteer' , 'kPhysical' , 'kPure' , 'kAzure' , 'kNetapp' , 'kAgent' , 'kGenericNas' , 'kAcropolis' , 'kPhysicalFiles' , 'kIsilon' , 'kKVM' , 'kAWS' , 'kExchange' , 'kHyperVVSS' , 'kOracle' , 'kGCP' , 'kFlashBlade' , 'kAWSNative' , 'kVCD' , 'kO365' , 'kO365Outlook' , 'kHyperFlex' , 'kGCPNative', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown')

write-host "Collecting report data..."

$jobs = api get protectionJobs?isDeleted=false

$title = "Strike Summary Backup Report"
$date = (get-date).ToString()

$html = '<html>
<head>
    <style>
        p {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        span {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        

        table {
            font-family: Arial, Helvetica, sans-serif;
            color: #333333;
            font-size: 0.75em;
            border-collapse: collapse;
            width: 100%;
        }

        tr {
            border: 1px solid #F1F1F1;
        }

        td,
        th {
            text-align: left;
            padding: 6px;
        }

        tr:nth-child(even) {
            background-color: #F1F1F1;
        }
    </style>
</head>
<body>
    
    <div style="margin:15px;">
            <img src="https://www.cohesity.com/wp-content/themes/cohesity/refresh_2018/templates/dist/images/footer/footer-logo-green.png" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'

$html += $title
$html += '</span>
<span style="font-size:0.75em; text-align: right; padding-top: 8px; padding-right: 2px; float: right;">'
$html += $date
$html += '</span>
</p>
<table>
<tr>
    <th>Object Name</th>
    <th>App Name</th>
    <th>Type</th>
    <th>Job Name</th>
    <th>Failure Count</th>
    <th>Last Good BU</th>
    <th>Last Error</th>
</tr>'

$errorsRecorded = 0

$errorCount = @{}
$latestError = @{}
$skip = @()
$lastSuccessful = @{}
$appErrors = @{}
$objErrors = @{}

foreach($job in $jobs){
    $objType = $job.environment
    $runs = api get "/backupjobruns?id=$($job.id)&startTimeUsecs=$(timeAgo 31 days)"
    foreach($protectionRun in $runs.backupJobRuns.protectionRuns){
        $runStartTimeUsecs = $protectionRun.copyRun[0].runStartTimeUsecs
        foreach($task in $protectionRun.backupRun.latestFinishedTasks){
            $objName = $task.base.sources[0].source.displayName
            $objStatus = $task.base.publicStatus
            if($objName -notin $skip -and $objStatus -eq 'kFailure'){
                $errorsRecorded += 1
                if($objName -notin $errorCount.Keys){
                    write-host "$objStatus  $($job.name)`t$objName"
                    $errorCount[$objName] = 1
                    $latestError[$objName] = $task.base.error.errorMsg
                    $appHtml = ''
                    if($task.psobject.properties['appEntityStateVec']){
                        foreach($app in $task.appEntityStateVec){
                            if($app.publicStatus -ne 'kSuccess'){
                                $appHtml += "<tr>
                                    <td></td>
                                    <td>$($app.appEntity.displayName)</td>
                                    <td>$($environments[$app.appEntity.type].subString(1))</td>
                                    <td></td>
                                    <td></td>
                                    <td></td>
                                    <td></td>
                                </tr>"
                            }
                        }
                    }
                    $appErrors[$objName] = $appHtml
                }else{
                    $errorCount[$objName] += 1
                }
                $jobId = $job.id
                $jobName = $job.name
                $jobUrl = "https://$vip/protection/job/$jobId/details"
                $jobEntry = "<a href=$jobUrl>$jobName</a>"
                $objErrors[$objName] = "<tr>
                    <td>$objName</td>
                    <td>-</td>
                    <td>$($objType.subString(1))</td>
                    <td>$jobEntry</td>
                    <td>$($errorCount[$objName])</td>
                    <td>$(usecsToDate $runStartTimeUsecs)</td>
                    <td>$($latestError[$objName])</td>
                </tr>"
            }else{
                $skip += $objName
            }
        }
    }
}

foreach($objName in ($errorCount.Keys | Sort-Object)){
    $html += $objErrors[$objName]
    if($objName -in $appErrors.Keys){
        $html += $appErrors[$objName]
    }
}

$html += '</table>
<p style="margin-top: 15px; margin-bottom: 15px;"><span style="font-size:1em;">Number of errors recorded: ' + $errorsRecorded + '</span></p>               
</div>
</body>
</html>
'

$html | out-file strikeReport.html

write-host "sending report to $([string]::Join(", ", $sendTo))"
### send email report
foreach($toaddr in $sendTo){
    Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "Backup Strike Report" -BodyAsHtml $html -Attachments ./strikeReport.html
}
