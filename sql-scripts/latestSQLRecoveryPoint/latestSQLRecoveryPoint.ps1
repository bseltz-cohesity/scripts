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
$job = api get "protectionJobs/$jobId"
return @{
    'jobName' = $job.name
    'jobId' = $jobId
    'jobRunId' = $version.instanceId.jobInstanceId
    'backupType' = $job.environmentParameters.sqlParameters.backupType
    'backupDateUsecs' = $version.snapshotTimestampUsecs
    'backupDate' = usecsToDate $version.snapshotTimestampUsecs
}