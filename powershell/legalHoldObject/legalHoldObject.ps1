# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][string]$jobName,  # folder to store export files
    [Parameter(Mandatory = $True)][string]$objectName,  # folder to store export files
    [Parameter()][switch]$removeHold,
    [Parameter()][switch]$addHold,
    [Parameter()][switch]$latest,
    [Parameter()][datetime]$startDate,
    [Parameter()][datetime]$endDate = (Get-Date),
    [Parameter()][int]$days = 0
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}



if($days -gt 0){
    $startTimeUsecs = timeAgo $days 'days'
}elseif($startTime){
    $startTimeUsecs = dateToUsecs $startDate
}else{
    $cluster = api get cluster
    $startTimeUsecs = ($cluster.createdTimeMsecs * 1000)
}

$endTimeUsecs = dateToUsecs $endDate

if($jobName){
    $job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object name -eq $jobName
    if($job){
        $jobId = $job.id
    }else{
        Write-Host "Job $jobName not found" -ForegroundColor Yellow
        exit 1
    }
}

$search = api get -v2 "data-protect/search/protected-objects?searchString=$objectName"
if($search.PSObject.Properties['objects'] -and $search.objects.Count -gt 0){
    foreach($obj in $search.objects){
        $snaps = api get -v2 "data-protect/objects/$($obj.id)/snapshots"
        foreach($snap in ($snaps.snapshots | Sort-Object -Property runStartTimeUsecs -Descending)){
            if(!$jobName -or $snap.protectionGroupId -eq $jobId){
                if($snap.runStartTimeUsecs -gt $startTimeUsecs -and $snap.runStartTimeUsecs -le $endTimeUsecs){
                    if($addHold){
                        $hold = $True
                        "Adding hold to $objectName ($($snap.protectionGroupName): $(usecsToDate $snap.runStartTimeUsecs))"
                    }else{
                        $hold = $False
                        "Removing hold from $objectName ($($snap.protectionGroupName): $(usecsToDate $snap.runStartTimeUsecs))"
                    }
                    $result = api put -v2 "data-protect/objects/$($obj.id)/snapshots/$($snap.id)" @{'setLegalHold' = $hold}
                }
                if($latest){
                    break
                }
            }
        }
    }
}else{
    Write-Host "Object $objectName not found" -ForegroundColor Yellow
}