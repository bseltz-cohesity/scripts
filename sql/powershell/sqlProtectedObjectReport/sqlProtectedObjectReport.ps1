[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][array]$jobname,
    [Parameter()][string]$joblist = '',
    [Parameter()][int]$days = 7,
    [Parameter()][switch]$includeLogs,
    [Parameter()][string]$smtpServer, # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, # outbound smtp port
    [Parameter()][array]$sendTo, # send to address
    [Parameter()][string]$sendFrom # send from address
)

# gather job names
$myjobs = @()
if($joblist -ne '' -and (Test-Path $joblist -PathType Leaf)){
    $myjobs += Get-Content $joblist | Where-Object {$_ -ne ''}
}elseif($jobList){
    Write-Warning "File $joblist not found!"
    exit 1
}
if($jobname){
    $myjobs += $jobname
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$cluster = api get cluster

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-sqlProtectedObjectReport-$dateString.csv"

"Cluster Name,Job Name,Environment,Object Name,Object Type,Parent,Policy Name,Frequency (Minutes),Run Type,Status,Start Time,End Time,Duration (Minutes),Expires,Job Paused,Object Message,Run Message" | Out-File -FilePath $outfileName

$policies = api get -v2 "data-protect/policies"
$jobs = (api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kSQL").protectionGroups

if($myjobs.Length -gt 0){
    $jobs = $jobs | Where-Object name -in $myjobs
}

$sources = api get protectionSources

$objects = @{}

"`nGathering Job Info from $($cluster.name)..."
foreach($job in $jobs | Sort-Object -Property name){
    "    $($job.name)"
    $policy = $policies.policies | Where-Object id -eq $job.policyId
    if($includeLogs){
        $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?includeObjectDetails=true&startTimeUsecs=$(timeAgo $days days)&numRuns=1000"
    }else{
        $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?runTypes=kIncremental,kFull&includeObjectDetails=true&startTimeUsecs=$(timeAgo $days days)&numRuns=1000"
    }
    if('kLog' -in $runs.runs.localBackupInfo.runType){
        $runDates = ($runs.runs | Where-Object {$_.localBackupInfo.runType -eq 'kLog'}).localBackupInfo.startTimeUsecs
    }else{
        $runDates = $runs.runs.localBackupInfo.startTimeUsecs
    }
    foreach($run in $runs.runs){
        $startTimeUsecs = $run.localBackupInfo.startTimeUsecs
        $endTimeUsecs = $run.localBackupInfo.endTimeUsecs
        foreach($thisobject in $run.objects){
            $object = $thisobject.object
            $localSnapshotInfo = $thisobject.localSnapshotInfo
            if($object.id -notin $objects.Keys){
                $objects[$object.id] = @{
                    'name' = $object.name;
                    'id' = $object.id;
                    'objectType' = $object.objectType;
                    'environment' = $object.environment;
                    'jobName' = $job.name;
                    'policyName' = $policy.name;
                    'jobEnvironment' = $job.environment;
                    'runDates' = $runDates;
                    'sourceId' = '';
                    'parent' = '';
                    'runs' = New-Object System.Collections.Generic.List[System.Object];              
                    'jobPaused' = $job.isPaused;
                    
                }
                if($object.PSObject.Properties['sourceId']){
                    $objects[$object.id].sourceId = $object.sourceId
                }
            }
            $message = ''
            $runmessage = ''
            $status = $localSnapshotInfo.snapshotInfo.status;
            if($run.PSObject.Properties['localBackupInfo'] -and $run.localBackupInfo.PSObject.Properties['messages'] -and $run.localBackupInfo.messages.Count -gt 0){
                $runmessage = $run.localBackupInfo.messages[0]
            }
            if($localSnapshotInfo.snapshotInfo.PSObject.Properties['warnings'] -and $localSnapshotInfo.snapshotInfo.warnings.Count -gt 0){
                $message = $localSnapshotInfo.snapshotInfo.warnings[0]
                $status = 'kWarning'
            }
            if($localSnapshotInfo.PSObject.Properties['failedAttempts'] -and $localSnapshotInfo.failedAttempts.Count -gt 0){
                $message = $localSnapshotInfo.failedAttempts[-1].message
                $status = 'kFailed'
            }
            
            $objects[$object.id].runs.Add(@{
                'protectionGroupName' = $run.protectionGroupName;
                'status' = $status; 
                'startTime' = $startTimeUsecs; 
                'endTime' = $endTimeUsecs;
                'expiry' = $localSnapshotInfo.snapshotInfo.expiryTimeUsecs;
                'runType' = $run.localBackupInfo.runType;
                'message' = $message;
                'runmessage' = $runmessage
            })
        }
    }
}

$report = @()

foreach($id in $objects.Keys){
    $object = $objects[$id]
    $parent = $null
    if($object.sourceId -ne ''){
        $parent = $objects[$object.sourceId]
        if(!$parent){
            $parent = $sources.protectionSource | Where-Object id -eq $object.sourceId
        }
    }
    if($parent -or ($object.environment -eq $object.jobEnvironment)){
        $object.parent = $parent.name
        if($object.runDates.count -gt 1){
            $frequency = [math]::Round((($object.runDates[0] - $object.runDates[-1]) / ($object.runDates.count - 1)) / (1000000 * 60))
        }else{
            $frequency = '-'
        }
        $lastRunDate = usecsToDate $object.runDates[0]
        if(!$parent){
            $object.parent = '-'
        }
        foreach($run in $object.runs){
            $status = $run.status.subString(1)
            $startTime = (usecsToDate $run.startTime).ToString('MM/dd/yyyy HH:mm')
            $endTime = (usecsToDate $run.endTime).ToString('MM/dd/yyyy HH:mm')
            if($run.expiry){
                $expireTime = (usecsToDate $run.expiry).ToString('MM/dd/yyyy HH:mm')
            }else{
                $expireTime = ''
            }
            
            $duration = [math]::Round(($run.endTime - $run.startTime) / (1000000 * 60))
            $runType = $run.runType.subString(1)
            $message = $run.message
            $report = @($report + ("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16}" -f $cluster.name, $run.protectionGroupName, $object.environment.subString(1), $object.name, $object.objectType.subString(1), $object.parent, $object.policyName, $frequency, $runType, $status, $startTime, $endTime, $duration, $expireTime, $object.jobPaused, $run.message, $run.runmessage))
        }
    }
}

$report | Out-File -FilePath $outfileName -Append
$report = Import-Csv -Path $outfileName
$report | Sort-Object -Property 'Cluster Name', 'Job Name', 'Object Name', @{Expression={$_.'Start Time'}; Descending=$True} | Export-Csv -Path $outfileName

"`nOutput saved to $outfilename`n"

if($smtpServer -and $sendTo -and $sendFrom){
    Write-Host "Sending report to $([string]::Join(", ", $sendTo))`n"

    # send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject 'Cohesity - SQL Protected Object Report' -Attachments $outfileName -WarningAction SilentlyContinue
    }
}
