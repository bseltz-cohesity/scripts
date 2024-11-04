### process commandline arguments
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
    [Parameter()][string]$startDate = '',
    [Parameter()][string]$endDate = '',
    [Parameter()][switch]$lastCalendarMonth,
    [Parameter()][int]$lastXDays = 0,
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom, #send from address
    [Parameter()][switch]$destroyable
)

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

### determine start and end dates
$today = Get-Date
if($startDate -ne '' -and $endDate -ne ''){
    $uStart = dateToUsecs $startDate
    $uEnd = dateToUsecs $endDate
}elseif ($lastXDays -ne 0) {
    $uStart = dateToUsecs ($today.AddDays(-$lastXDays))
    $uEnd = dateToUsecs $today.AddSeconds(-1)
}elseif ($lastCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddMonths(-1))
    $uEnd = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddSeconds(-1))
}else{
    $uStart = dateToUsecs ($today.Date.AddDays(-31))
    $uEnd = dateToUsecs $today.AddSeconds(-1)
}

$start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
$end = (usecsToDate $uEnd).ToString('yyyy-MM-dd')

$cluster = api get cluster

$title = "Restore Report for $($cluster.name) ($start - $end)"

$date = (get-date).ToString()

$now = (Get-Date).ToString("yyyy-MM-dd")
$csvFile = "restoreReport-$($cluster.name)-$now.csv"

"Date,Task,Object,Type,Target,Status,Duration (Min),Restore Point,User" | Out-File $csvFile

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
            width: 33%;
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
            <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAARgAAAAoCAMAAAASXRWnAAAC8VBMVE
            WXyTz///+XyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTwJ0VJ2AAAA+nRSTlMAAAECAwQFBgcICQoLDA0ODxARExQVFhcYGRobHB0eHy
            EiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj9AQUNERUZHSElKS0xNTk9QUVJTVFVWV1hZWl
            tcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9foCBgoOEhYaHiImKi4yNjo+QkZKTlJ
            WWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc
            7Q0dLT1NXW19jZ2tvc3d7f4OHi4+Xm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+drbbjAAACOZJRE
            FUaIHtWmlcVUUUv6alIgpiEGiZZIpiKu2i4obhUgipmGuihuZWiYmkRBu4JJVappaG5VJRUWrllq
            ZWivtWVuIWllHwShRI51PvnjP33pk7M1d579Gn/j8+zDnnf2b5v3tnu2g1/ocUmvuPRasx83cVu1
            zFB5endtWUCHgoM/+0y1V64sOZcXVlhMDpWXdLM+PmPnmdZTVJeLCPiL6Jd9jT6nfo2y+hH4vE/h
            Fcj6bP6uhcqxvxfYzOdsxOb6gYm39qdrRmE6bBxB2EQWHOXfLBvVvMsIqWdBEYzYvcgWRJ6nS3f5
            +/YSWXEQVeYJPqpXx5XkaaalFuOu22h2E5UVkrIadaAyXFXTwbKh1cw0J3bCgvzFO/CRWtuk3IjP
            lKYK23C7ga3IFCblPwp1HrNvUAyH1W0tRzKlIbk/OmbpbX04uNHGp1/9j6MxMMxUNSYXbqoTJWmF
            t3yCqqHGVLzJK2l8qTtoOzldBqD/C/Ra3hDgOYZKTU2awmpZgVbwG7udWGEvovHYXFHIkuYzHECN
            Pzb0VNy9g8/60KVh5X/QbwtRCajQH//GsQ5k7KCTzqQGprVrwW7HC9GOKQQMhpP30UpWiIM0XYZQ
            gcsYR50Mo9vj73vS9+sOy1Vl6A5S7auXJ53v4Lpr2Trf9LcN0utNsZ/K9Ra4iy++XGE+h3zGGQaV
            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
            8LK0YAAAAASUVORK5CYII=" style="width:180px">
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
        <th>Date</th>
        <th>Task</th>
        <th>Object</th>
        <th>Type</th>
        <th>Target</th>
        <th>Status</th>
        <th>Duration (Min)</th>
        <th>Restore Point</th>
        <th>User</th>
      </tr>'

$entityType=@('Unknown', 'VMware', 'HyperV', 'SQL', 'View', 'Puppeteer',
              'Physical', 'Pure', 'Azure', 'Netapp', 'Agent', 'GenericNas',
              'Acropolis', 'PhysicalFiles', 'Isilon', 'KVM', 'AWS', 'Exchange',
              'HyperVVSS', 'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
              'O365', 'O365Outlook', 'HyperFlex', 'GCPNative', 'AzureNative', 
              'AD', 'AWSSnapshotManager', 'GPFS', 'RDSSnapshotManager', 'Kubernetes',
              'Nimble', 'AzureSnapshotManager', 'Elastifile', 'Cassandra', 'MongoDB',
              'HBase', 'Hive', 'Hdfs', 'Couchbase', 'Unknown', 'Unknown', 'Unknown')

$endUsecs = $uEnd

$restoresCounted = 0
$endUsecs = $uEnd
$lastUsecs = 0
$lastTaskId = 0

function output($startTime, $taskName, $objectName, $objectType, $targetObject, $status, $duration, $restorePoint, $baseuser, $link){
    if($status -eq 'Failure'){
        $script:html += "<tr style='color:BA3415;'>"
    }else{
        $script:html += "<tr>"
    }
    $script:html += "<td>$startTime</td>
    <td><a href=$link target=""_blank"">$taskName</a></td>
    <td>$objectName</td>
    <td>$objectType</td>
    <td>$targetObject</td>
    <td>$status</td>
    <td>$duration</td>
    <td>$restorePoint</td>
    <td>$baseuser</td>
    </tr>"
    "$startTime,$taskName,$objectName,$objectType,$targetObject,$status,$duration,$restorePoint,$baseuser" | out-file $csvFile -Append
}

function getTarget($app){
    $appParams = $app.restoreParams
    $objectName = $app.appEntity.displayName
    $objectType = $entityType[$app.appEntity.type]
    if($appParams.targetHost.displayName){
        $targetServer = $appParams.targetHost.displayName
    }
    $targetObject = $targetServer
    if($appParams.sqlRestoreParams.instanceName){
        $targetObject += "/$($appParams.sqlRestoreParams.instanceName)"
    }
    if($appParams.sqlRestoreParams.newDatabaseName){
        $targetObject += "/$($appParams.sqlRestoreParams.newDatabaseName)"
    }
    if($targetObject -eq $targetServer){
        $targetObject = "$targetServer/$objectName"
    }
    return $targetObject, $objectName, $objectType
}

while(1){
    $restores = api get "/restoretasks?_includeTenantInfo=true&endTimeUsecs=$endUsecs&startTimeUsecs=$uStart"
    $theseRestores = $restores
    if($destroyable){
        $theseRestores = $theseRestores | Where-Object {$_.restoreTask.performRestoreTaskState.canTeardown -eq $True}
        $theseRestores = $theseRestores | Where-Object {$_.restoreTask.destroyClonedTaskStateVec.Count -eq 0}
    }
    foreach ($restore in $theseRestores | Sort-Object -Property {$_.restoreTask.performRestoreTaskState.base.startTimeUsecs} -Descending){
        $restorePoint = ''
        $state = $restore.restoreTask.performRestoreTaskState
        $base = $state.base
        if($base -ne $null){
            $taskId = $base.taskId
            if($taskId -ne $lastTaskId){
                $lastTaskId = $taskId
                $taskName = $base.name
                $status = ($base.publicStatus).Substring(1)
                $startTime = usecsToDate $base.startTimeUsecs
                $duration = '-'
                if($base.PSObject.properties['endTimeUsecs']){
                    $endTime = usecsToDate $base.endTimeUsecs
                    $duration = [math]::Round(($endTime - $startTime).TotalMinutes)
                    $endUsecs = $base.endTimeUsecs - 1
                }
                $restoreType = ($base.userInfo.pulseAttributeVec | Where-Object {$_.key -eq 'taskType'}).value.data.stringValue
                if($restoreType -eq 'clone'){
                    $link = "https://$vip/more/devops/clone/detail/$taskId"
                }else{
                    $link = "https://$vip/recovery/detail/$($cluster.id):$($cluster.incarnationId):$($taskId)"
                }
                if($state.PSObject.properties['objects']){
                    foreach ($object in $state.objects){
                        $restorePoint = ''
                        # $object.entity | toJson
                        $objectType = $entityType[$object.entity.type]
                        # $objectType
                        $targetObject = $objectName = $object.entity.displayName
                        $restorePoint = usecsToDate $object.startTimeUsecs
                        # vmware prefix/suffix
                        if($state.renameRestoredObjectParam.prefix){
                            $targetObject = "$($state.renameRestoredObjectParam.prefix)$targetObject"
                        }
                        if($state.renameRestoredObjectParam.suffix){
                            $targetObject = "$targetObject$($state.renameRestoredObjectParam.suffix)"
                        }
                        # netapp, isilon, genericNas
                        if($state.restoreInfo.type -in @(9, 11, 14)){
                            $targetObject = $state.fullViewName
                        }
                        output $startTime $taskName $objectName $objectType $targetObject $status $duration $restorePoint $base.user $link
                        $restoresCounted += 1
                    }
                }elseif($state.PSObject.properties['restoreAppTaskState']){
                    $appState = $state.restoreAppTaskState
                    if($appState.PSObject.Properties['childRestoreAppParamsVec']){
                        foreach ($childRestore in $appState.childRestoreAppParamsVec){
                            $restorePoint = usecsToDate $childRestore.ownerRestoreInfo.ownerObject.startTimeUsecs
                            $targetServer = $sourceServer = $childRestore.ownerRestoreInfo.ownerObject.entity.displayName                    
        
                            foreach($app in $childRestore.restoreAppObjectVec){
                                $targetObject, $objectName, $objectType = getTarget($app)
                                output $startTime $taskName "$sourceServer/$objectName" $objectType $targetObject $status $duration $restorePoint $base.user $link
                                $restoresCounted += 1
                            }
                        }
                    }
                    if($appState.PSObject.Properties['restoreAppParams']){
        
                        foreach ($app in $appState.restoreAppParams.restoreAppObjectVec){
                            $restorePoint = usecsToDate $appState.restoreAppParams.ownerRestoreInfo.ownerObject.startTimeUsecs
                            $targetServer = $sourceServer = $appState.restoreAppParams.ownerRestoreInfo.ownerObject.entity.displayName
                            $targetObject, $objectName, $objectType = getTarget($app)
                            output $startTime $taskName "$sourceServer/$objectName" $objectType $targetObject $status $duration $restorePoint $base.user $link
                            $restoresCounted += 1
                        }
                    }
                }else{
                    "***************more types****************"
                }
            }
        }
    }
    if(!$restores -or $lastUsecs -eq $endUsecs){
        Write-Host "Retrieved $restoresCounted restore tasks..."
        break
    }else{
        $lastUsecs = $endUsecs
        $endUsecs = $base.startTimeUsecs
    }
}

$html += "</table>                
</div>
</body>
</html>"

$html | out-file "restoreReport-$($cluster.name)-$($now).html"

"Saving output to restoreReport-$($cluster.name)-$now.html and restoreReport-$($cluster.name)-$now.csv"

if($smtpServer -and $sendFrom -and $sendTo){
    write-host "sending report to $([string]::Join(", ", $sendTo))"

    ### send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $html -WarningAction SilentlyContinue
    }
}
