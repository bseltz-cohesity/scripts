[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int64]$pageSize = 100
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$nowUsecs = dateToUsecs (Get-Date)
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-SQLRecoveryPoints-$dateString.csv"
"Job Name,Server,Instance,Database,Snapshot Date,Local Expiry,Oldest PIT,Newest PIT,Archival Expiry,Archive Target" | Out-File -FilePath $outfileName

### find recoverable objects
$from = 0
$ro = api get "/searchvms?environment=SQL&size=$pageSize&from=$from"

if($ro.count -gt 0){

    while($True){
        $ro.vms | Where-Object {$_.vmDocument.objectId.entity.type -eq 3} | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
            $doc = $_.vmDocument
            $jobId = $doc.objectId.jobId
            $jobName = $doc.jobName
            $objName = $doc.objectName
            $serverName = $doc.objectAliases[0]
            $instanceName, $dbName = $objName -split '/'
            write-host ("`n{0}: {1}/{2} on {3}" -f $jobName, $instanceName, $dbName, $serverName) -ForegroundColor Green 
            $versionList = @()
            foreach($version in $doc.versions){
                $runId = $version.instanceId.jobInstanceId
                $startTime = $version.instanceId.jobStartTimeUsecs
                $local = 0
                $remote = 0
                $remoteCluster = ''
                $archive = 0
                $archiveTarget = ''
                foreach($replica in $version.replicaInfo.replicaVec){
                    if($replica.target.type -eq 1){
                        $local = $replica.expiryTimeUsecs
                    }elseif($replica.target.type -eq 3) {
                        if($replica.expiryTimeUsecs -gt $archive){
                            $archive = $replica.expiryTimeUsecs
                            $archiveTarget = $replica.target.archivalTarget.name
                        }
                    }
                }
                # get latest log pit
                $oldestPointInTime = $null
                $newestPointInTime = $null
                $timeRangeQuery = @{
                    "endTimeUsecs"       = $nowUsecs;
                    "protectionSourceId" = $doc.objectId.entity.id;
                    "environment"        = "kSQL";
                    "jobUids"            = @(
                        @{
                            "clusterId"            = $doc.objectId.jobUid.clusterId;
                            "clusterIncarnationId" = $doc.objectId.jobUid.clusterIncarnationId;
                            "id"                   = $doc.objectId.jobUid.objectId
                        }
                    );
                    "startTimeUsecs"     = $startTime
                }
                $pointsForTimeRange = api post restore/pointsForTimeRange $timeRangeQuery
                if($pointsForTimeRange.PSobject.Properties['timeRanges']){
                    $logStart = $pointsForTimeRange.timeRanges[0].startTimeUsecs
                    $logEnd = $pointsForTimeRange.timeRanges[0].endTimeUsecs
                    if($pointsForTimeRange.fullSnapshotInfo.count -eq 1 -or $pointsForTimeRange.fullSnapshotInfo[-2].restoreInfo.startTimeUsecs -gt $logStart){
                        $oldestPointInTime = usecsToDate $logStart
                        $newestPointInTime = usecsToDate $logEnd
                    }
                }
                $versionList += @{'RunDate' = $startTime; 
                                  'local' = $local; 
                                  'archive' = $archive; 
                                  'archiveTarget' = $archiveTarget; 
                                  'runId' = $runId; 
                                  'startTime' = $startTime;
                                  'oldestPointInTime' = $oldestPointInTime;
                                  'newestPointInTime' = $newestPointInTime}
            }
            write-host "`n`t             RunDate           SnapExpires        ArchiveExpires" -ForegroundColor Blue
            foreach($version in $versionList){
                if($version['local'] -eq 0){
                    $local = '-'
                }else{
                    $local = usecsToDate $version['local']
                }
                if($version['archive'] -eq 0){
                    $archive = '-'
                }else{
                    $archive = usecsToDate $version['archive']
                }
                $runDate = usecsToDate $version['RunDate']
                "`t{0,20}  {1,20}  {2,20}" -f $runDate, $local, $archive
                $oldestLog = ''
                if($version['oldestPointInTime'] -ne $null){
                    $oldestLog = $version['oldestPointInTime']
                }
                $newestLog = ''
                if($version['newestPointInTime'] -ne $null){
                    $newestLog = $version['newestPointInTime']
                }
                "$jobName,$serverName,$instanceName,$dbName,$runDate,$local,$oldestLog,$newestLog,$archive,$($version['archiveTarget'])" | Out-File -FilePath $outfileName -Append
            }
        }
        if($ro.count -gt ($pageSize + $from)){
            $from += $pageSize
            $ro = api get "/searchvms?environment=SQL&size=$pageSize&from=$from"
        }else{
            break
        }
    }
    write-host "`nReport Saved to $outFileName`n" -ForegroundColor Blue
}
