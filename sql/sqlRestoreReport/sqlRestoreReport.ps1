### process commandline arguments
[CmdletBinding()]
param (
   [Parameter()][array]$vip = 'helios.cohesity.com', #the cluster to connect to (DNS name or IP)
   [Parameter()][string]$username = 'helios', #username (local or AD)
   [Parameter()][array]$clusterName,
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][switch]$useApiKey,                     # use API key for authentication
   [Parameter()][string]$password,                      # optional password
   [Parameter()][switch]$noPrompt,                      # do not prompt for password
   [Parameter()][string]$startDate = '',
   [Parameter()][string]$endDate = '',
   [Parameter()][switch]$lastCalendarMonth,
   [Parameter()][int]$lastXDays = 0,
   [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'MiB',
   [Parameter()][switch]$includeClones,
   [Parameter()][string]$nameMatch = '',
   [Parameter()][string]$targetServer,
   [Parameter()][ValidateSet('Success','Failure','Canceled','Running','Accepted','All')][string]$status = 'All',
   [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
   [Parameter()][string]$smtpPort = 25, #outbound smtp port
   [Parameter()][array]$sendTo, #send to address
   [Parameter()][string]$sendFrom #send from address
)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

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

$title = "SQL Restore Report for $($cluster.name) ($start - $end)"

$date = (get-date).ToString()

$now = (Get-Date).ToString("yyyy-MM-dd")
$csvFile = "sqlRestoreReport-$now.tsv"

"Cluster Name`tDate`tTask`tObject`tSize ($unit)`tTarget`tStatus`tDuration (Min)`tUser" | Out-File $csvFile

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
$html += "</span>
</p>
<table>
<tr>
    <th>Cluster Name</th>
    <th>Date</th>
    <th>Task</th>
    <th>Object</th>
    <th>Size ($unit)</th>
    <th>Target</th>
    <th>Status</th>
    <th>Duration (Min)</th>
    <th>User</th>
</tr>"

$entityType=@('Unknown', 'VMware', 'HyperV', 'SQL', 'View', 'Puppeteer',
              'Physical', 'Pure', 'Azure', 'Netapp', 'Agent', 'GenericNas',
              'Acropolis', 'PhysicalFiles', 'Isilon', 'KVM', 'AWS', 'Exchange',
              'HyperVVSS', 'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
              'O365', 'O365Outlook', 'HyperFlex', 'GCPNative', 'AzureNative', 
              'AD', 'AWSSnapshotManager', 'GPFS', 'RDSSnapshotManager', 'Kubernetes',
              'Nimble', 'AzureSnapshotManager', 'Elastifile', 'Cassandra', 'MongoDB',
              'HBase', 'Hive', 'Hdfs', 'Couchbase', 'Unknown', 'Unknown', 'Unknown')

foreach($v in $vip){
    ### authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -noPromptForPassword $noPrompt -quiet

    if($USING_HELIOS -and ! $clusterName){
        $clusterName = @((heliosClusters).name)
    }

    if(!$cohesity_api.authorized){
        Write-Host "$v Not authenticated" -ForegroundColor Yellow
    }else{
        if(!$USING_HELIOS){
            $clusterName = @((api get cluster).name)
        }
        foreach($cluster in $clusterName){
            if($USING_HELIOS){
                $null = heliosCluster $cluster
            }
            $thisCluster = api get cluster
            $restoresCount = 0
            $lastTaskId = 0
            $endUsecs = $uEnd
            while(1){
                $restores = api get "/restoretasks?restoreTypes=kRestoreApp&_includeTenantInfo=true&endTimeUsecs=$endUsecs&startTimeUsecs=$uStart"
                foreach ($restore in $restores | Where-Object {$_ -ne $null} | Sort-Object -Property {$_.restoreTask.performRestoreTaskState.base.startTimeUsecs} -Descending){
                    $taskId = $restore.restoreTask.performRestoreTaskState.base.taskId
                    $taskName = $restore.restoreTask.performRestoreTaskState.base.name
                    if($nameMatch -eq '' -or $taskName -match $nameMatch){
                        $thisstatus = $restore.restoreTask.performRestoreTaskState.base.publicStatus
                        if($thisstatus -ne $null){
                            $thisstatus = $thisstatus.subString(1)
                        }else{
                            continue
                        }
                        if($status -eq 'All' -or $thisstatus -eq $status){
                            $startTime = usecsToDate $restore.restoreTask.performRestoreTaskState.base.startTimeUsecs
                            $duration = '-'
                            if($restore.restoreTask.performRestoreTaskState.base.PSObject.properties['endTimeUsecs']){
                                $endTime = usecsToDate $restore.restoreTask.performRestoreTaskState.base.endTimeUsecs
                                $duration = [math]::Round(($endTime - $startTime).TotalMinutes)
                                $endUsecs = $restore.restoreTask.performRestoreTaskState.base.endTimeUsecs - 1
                            }
                            $link = "https://$cluster/protection/recovery/detail/local/$taskId/"
                            if($thisCluster.clusterSoftwareVersion -gt '6.8.1'){
                                $link = "https://$cluster/recovery/detail/$($thisCluster.id):$($thisCluster.incarnationId):$($taskId)"
                            }
                            if($restore.restoreTask.performRestoreTaskState.PSObject.properties['restoreAppTaskState']){
                                if($restore.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.PSObject.Properties['restoreAppObjectVec']){
                                    $thisTargetServer = $sourceServer = $restore.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.ownerRestoreInfo.ownerObject.entity.displayName
                                    $restoreAppObjects = $restore.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec
                                }else{
                                    $thisTargetServer = $sourceServer = $restore.restoreTask.performRestoreTaskState.restoreAppTaskState.childRestoreAppParamsVec[0].ownerRestoreInfo.ownerObject.entity.displayName
                                    $restoreAppObjects = $restore.restoreTask.performRestoreTaskState.restoreAppTaskState.childRestoreAppParamsVec.restoreAppObjectVec  # childRestoreAppParamsVec[0]
                                }
                                $v2Recovery = $null
                                if($thisstatus -eq 'Failure'){
                                    $v2Recoveries = api get -v2 "data-protect/recoveries?returnOnlyChildRecoveries=true&includeTenants=true&ids=$($thisCluster.id)%3A$($thisCluster.incarnationId)%3A$($taskId)"
                                }
                                foreach ($restoreAppObject in $restoreAppObjects){
                                    $objectName = $restoreAppObject.appEntity.displayName
                                    $thisChildStatus = $thisstatus
                                    if($v2Recoveries){
                                        $v2Recovery = $v2Recoveries.recoveries | Where-Object {$_.mssqlParams.recoverAppParams[0].objectInfo.name -eq $objectName}
                                        if($v2Recovery){
                                            $thisChildStatus = $v2Recovery.status
                                        }
                                    }

                                    $objectType = $entityType[$restoreAppObject.appEntity.type]
                                    if($objectType -eq 'SQL' -and ($includeClones -or $restore.restoreTask.performRestoreTaskState.base.type -eq 4)){
                                        $totalSize = toUnits $restoreAppObject.appEntity.sqlEntity.totalSizeBytes
                                        if($restoreAppObject.restoreParams.targetHost.displayName){
                                            $thisTargetServer = $restoreAppObject.restoreParams.targetHost.displayName
                                        }
                                        $targetObject = $thisTargetServer
                                        # sql target
                                        if($restoreAppObject.restoreParams.sqlRestoreParams.instanceName){
                                            $targetObject += "/$($restoreAppObject.restoreParams.sqlRestoreParams.instanceName)"
                                        }
                                        if($restoreAppObject.restoreParams.sqlRestoreParams.newDatabaseName){
                                            $targetObject += "/$($restoreAppObject.restoreParams.sqlRestoreParams.newDatabaseName)"
                                        }
                                        if($targetObject -eq $thisTargetServer){
                                            $targetObject = "$thisTargetServer/$objectName"
                                        }
                                        if(! $targetServer -or $targetServer -eq $thisTargetServer){
                                            if($thisChildStatus -in @('Failure', 'Failed')){
                                                $html += "<tr style='color:BA3415;'>"
                                            }elseif($thisChildStatus -eq 'Canceled'){
                                                $html += "<tr style='color:FF9800;'>"
                                            }else{
                                                $html += "<tr>"
                                            }
                                            $html += "<td>$cluster</td>
                                            <td>$startTime</td>
                                            <td><a href=$link>$taskName</a></td>
                                            <td>$sourceServer/$objectName</td>
                                            <td>$totalSize</td>
                                            <td>$targetObject</td>
                                            <td>$thisChildStatus</td>
                                            <td>$duration</td>
                                            <td>$($restore.restoreTask.performRestoreTaskState.base.user)</td>
                                            </tr>"
                                            "$cluster`t$startTime`t$taskName`t$objectName`t$totalSize`t$targetObject`t$thisChildStatus`t$duration`t$($restore.restoreTask.performRestoreTaskState.base.user)" | out-file $csvFile -Append
                                            $restoresCount += 1 
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if($lastTaskId -eq $taskId){
                    break
                }else{
                    $lastTaskId = $taskId
                    Write-Host "$($cluster): retrieved $($restoresCount) restore tasks..."
                    break
                }
            }
        }
    }
}

$html += "</table>                
</div>
</body>
</html>"

$html | out-file "sqlRestoreReport-$($now).html"

"Saving output to sqlRestoreReport-$now.html and sqlRestoreReport-$now.tsv"

if($smtpServer -and $sendFrom -and $sendTo){
    write-host "sending report to $([string]::Join(", ", $sendTo))"

    ### send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $html -WarningAction SilentlyContinue
    }
}
