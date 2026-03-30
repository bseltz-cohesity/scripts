# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory=$True)][string]$filePath,
    [Parameter()][string]$jobName,
    [Parameter()][string]$jobType,
    [Parameter()][string]$sourceServer,
    [Parameter()][int]$showVersions,
    [Parameter()][int]$runId
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$jobs = api get protectionJobs

$encodedFile = [System.Web.HttpUtility]::UrlEncode($filePath).Replace('%2F%2F','%2F').replace('%2f','%2F')

$searchUrl = "/searchfiles?filename=$encodedFile"

if($jobName){
    $job = $jobs | Where-Object name -eq $jobName
    if(!$job){
        Write-Host "Job $jobName not found" -ForegroundColor Yellow
        exit
    }else{
        $searchUrl = "$($searchUrl)&jobIds=$($job[0].id)"
    }
}
if($jobType){
    $searchUrl = "$($searchUrl)&entityTypes=$($jobType)"
}

$search = api get $searchUrl

$x = 0
foreach($file in $search.files){
    $job = $jobs | Where-Object id -eq $file.fileDocument.objectId.jobId
    if($job){
        if(!$sourceServer -or $sourceServer -eq $file.fileDocument.objectId.entity.displayName){
            $clusterId = $file.fileDocument.objectId.jobUid.clusterId
            $clusterIncarnationId = $file.fileDocument.objectId.jobUid.clusterIncarnationId
            $entityId = $file.fileDocument.objectId.entity.id
            $jobId = $file.fileDocument.objectId.jobId
            if($runId -or ($showVersions -eq $x)){
                $versions = api get "/file/versions?clusterId=$clusterId&clusterIncarnationId=$clusterIncarnationId&entityId=$entityId&filename=$encodedFile&fromObjectSnapshotsOnly=false&jobId=$jobId"
            }
            if($runId -and ($runId -notin $versions.versions.instanceId.jobInstanceId)){
                continue
            }
            $x += 1
            if($showVersions -eq $x){
                $versions.versions | Format-Table -Property @{label="runId"; expression={$_.instanceId.jobInstanceId}}, @{label="startDate"; expression={usecsToDate $_.instanceId.jobStartTimeUsecs}}
                exit
            }else{
                Write-Host "$($x): $($job[0].name) / $($file.fileDocument.objectId.entity.displayName) -> $($file.fileDocument.fileName)"
            }
        }
    }
}

if(!$showVersions){
    Write-Host "`n$x files found`n"
}
