### usage: ./latestSQLRecoveryPoint.ps1 -vip mycluster `
#                                       -username myusername `
#                                       -domain mydomain.net `
#                                       -serverName myserver.mydomain.net `
#                                       -dbName mydatabase

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$serverName,
    [Parameter(Mandatory = $True)][string]$dbName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

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
