[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')

$cluster = api get cluster

$nowUsecs = dateToUsecs (Get-Date)
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-sqlObjectProtectionStatus-$dateString.csv"
"SQL Server,Database,Recovery Model,AAG Name,Protected,Job Name,Policy Name,Last DB Backup,Last PIT,Latest Expiry,Last DB Status,Last Log Status" | Out-File -FilePath $outfileName
$rootSource = api get protectionSources?environment=kSQL

foreach($sqlServer in $rootSource.nodes | Sort-Object -Property {$_.protectionSource.name}){
    $serverName = $sqlServer.protectionSource.name
    $serverId = $sqlServer.protectionSource.id
    $protectedObjects = api get "protectionSources/protectedObjects?environment=kSQL&id=$serverId"
    foreach($instance in $sqlServer.applicationNodes | Sort-Object -Property {$_.protectionSource.name}){
        $instanceName = $instance.protectionSource.name
        foreach($db in $instance.nodes | Sort-Object -Property {$_.protectionSource.name}){
            $aagName = ''
            $aagName = $db.protectionSource.sqlProtectionSource.dbAagName
            $recoveryModel = $db.protectionSource.sqlProtectionSource.recoveryModel.subString(1).split('RecoveryModel')[0]
            $protectionStatus = 'FALSE'
            $dbName = $db.protectionSource.name
            $dbShortName = $dbName.split('/')[-1]
            $protectedDb = $protectedObjects | Where-Object {$_.protectionSource.name -eq $dbName}
            if($protectedDb){
                $protectionStatus = 'TRUE'
                $job = $protectedDb.protectionJobs[0]
                $jobName = $job.name
                $jobId= $job.id
                $policy = $protectedDb.protectionPolicies | Where-Object id -eq $job.policyId
                $policyName = $policy.name

                $newestBackupDateTime = ''
                $newestPointInTime = ''
                $newestExpiry = ''
                $lastRunDBStatus = ''
                $lastLogrunDBStatus = ''

                # get available DB backups
                $searchresults = api get "/searchvms?environment=SQL&entityTypes=kSQL&entityTypes=kVMware&vmName=$dbName"
                $dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $serverName } | `
                                Where-Object { $_.vmDocument.objectId.entity.displayName -eq $dbName } | `
                                Sort-Object -Property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $false;}
                if($dbresults.Count -gt 0){
                    $newestBackup = $dbresults[0].vmDocument.versions[0]
                    $newestBackupTime = $newestBackup.snapshotTimestampUsecs
                    $newestBackupDateTime = usecsToDate $newestBackupTime
                    $newestExpiry = usecsToDate ([int64]($newestBackup.replicaInfo.replicaVec.expiryTimeUsecs | measure -Maximum).Maximum)
                    # get latest log pit
                    $timeRangeQuery = @{
                        "endTimeUsecs"       = $nowUsecs;
                        "protectionSourceId" = $dbresults[0].vmDocument.objectId.entity.id;
                        "environment"        = "kSQL";
                        "jobUids"            = @(
                            @{
                                "clusterId"            = $dbresults[0].vmDocument.objectId.jobUid.clusterId;
                                "clusterIncarnationId" = $dbresults[0].vmDocument.objectId.jobUid.clusterIncarnationId;
                                "id"                   = $dbresults[0].vmDocument.objectId.jobUid.objectId
                            }
                        );
                        "startTimeUsecs"     = $newestBackupTime
                    }
                    $pointsForTimeRange = api post restore/pointsForTimeRange $timeRangeQuery
                    if($pointsForTimeRange.PSobject.Properties['timeRanges']){
                        $logEnd = $pointsForTimeRange.timeRanges[0].endTimeUsecs
                        $newestPointInTime = usecsToDate $logEnd
                    }
                }
                # get last run outcome
                $runs = api get "protectionRuns?jobId=$jobId&runTypes=kRegular&runTypes=kFull&numRuns=2" | Where-Object {$_.backupRun.status -in $finishedStates}
                if($runs.Count -gt 0){
                    $sourceStatus = $runs[0].backupRun.sourceBackupStatus | Where-Object {$_.source.name -eq $serverName}
                    if($sourceStatus){
                        $appStatus = $sourceStatus.appsBackupStatus | where-object {$_.name -eq $dbName -and $_.ownerId -eq $sourceStatus.source.id}
                        if($appStatus){
                            $lastRunDBStatus = $appStatus.status.subString(1)
                            if($lastRunDBStatus -eq 'Success' -and $newestBackupDateTime -eq ''){
                                $newestBackupDateTime = usecsToDate $runs[0].backupRun.stats.startTimeUsecs
                                $newestExpiry = usecsToDate (($runs[0].copyRun | Where-Object {$_.target.type -eq 'kLocal'}).expiryTimeUsecs)
                            }
                        }
                    }
                }
                # get last log run outcome
                $logruns = api get "protectionRuns?jobId=$jobId&runTypes=kLog&numRuns=2" | Where-Object {$_.backupRun.status -in $finishedStates}
                if($logruns.Count -gt 0){
                    $sourceStatus = $logruns[0].backupRun.sourceBackupStatus | Where-Object {$_.source.name -eq $serverName}
                    if($sourceStatus){
                        $appStatus = $sourceStatus.appsBackupStatus | where-object {$_.name -eq $dbName}
                        if($appStatus){
                            $lastLogrunDBStatus = $appStatus.status.subString(1)
                            if($lastLogrunDBStatus -eq 'Success' -and $newestPointInTime -eq ''){
                                $newestPointInTime = usecsToDate $run.backupRun.stats.startTimeUsecs
                            }
                        }
                    }
                }
                "{0}  {1} (protected)" -f $serverName, $dbName
                """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}""" -f $serverName, $dbName, $recoveryModel, $aagName, $protectionStatus, $jobName, $policyName, $newestBackupDateTime, $newestPointInTime, $newestExpiry, $lastRunDBStatus, $lastLogrunDBStatus | Out-File -FilePath $outfileName -Append       
            }else{
                "{0}  {1}" -f $serverName, $dbName
                """{0}"",""{1}"",""{2}"",""{3}"",""{4}""" -f $serverName, $dbName, $recoveryModel, $aagName, $protectionStatus | Out-File -FilePath $outfileName -Append
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
