### usage: ./latestSQLRecoveryPoint.ps1 -vip mycluster `
#                                       -username myusername `
#                                       -domain mydomain.net `
#                                       -serverName myserver.mydomain.net `
#                                       -dbName mydatabase

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$serverName,
    [Parameter(Mandatory = $True)][string]$dbName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$searchresults = api get /searchvms?environment=SQL`&entityTypes=kSQL`&entityTypes=kVMware`&vmName=$dbName

$dbresults = $searchresults.vms | Where-Object {$serverName -in $_.vmDocument.objectAliases } |
                                  Where-Object { $_.vmDocument.objectId.entity.sqlEntity.databaseName -eq $dbName }

if($null -eq $dbresults){
    write-host "Database $dbName on Server $serverName Not Found" -foregroundcolor yellow
    exit 1
}

# if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

$doc = $latestdb.vmDocument
$version = $doc.versions[0]
$jobId = $doc.objectId.jobId
$dbId = $doc.objectId.entity.id

$job = api get "protectionJobs/$jobId"

# get last log backup
$latestPIT = usecsToDate $version.snapshotTimestampUsecs

$logUsecsDayStart = [int64]($version.snapshotTimestampUsecs)
$logUsecsDayEnd = [int64]( dateToUsecs (get-date))

$timeRangeQuery = @{
    "endTimeUsecs"       = $logUsecsDayEnd;
    "protectionSourceId" = $dbId;
    "environment"        = "kSQL";
    "jobUids"            = @(
        @{
            "clusterId"            = $doc.objectId.jobUid.clusterId;
            "clusterIncarnationId" = $doc.objectId.jobUid.clusterIncarnationId;
            "id"                   = $doc.objectId.jobUid.objectId
        }
    );
    "startTimeUsecs"     = $logUsecsDayStart
}

$pointsForTimeRange = api post restore/pointsForTimeRange $timeRangeQuery
if($pointsForTimeRange.PSobject.Properties['timeRanges']){
    $timeRange = $pointsForTimeRange.timeRanges[0]
    $logEnd = $timeRange.endTimeUsecs
    $latestUsecs = $logEnd - 1000000
    $latestPIT = usecsToDate $latestUsecs
}

Write-Host  "`n            Job Name: $($job.name) ($($job.environmentParameters.sqlParameters.backupType))"
Write-Host  "      Last DB Backup: $(usecsToDate $version.snapshotTimestampUsecs)"
Write-Host  "Latest Point In Time: $latestPIT`n"
