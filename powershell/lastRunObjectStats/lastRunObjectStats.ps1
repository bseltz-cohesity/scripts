[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'GiB',
    [Parameter()][switch]$localOnly
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}

function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "lastRun-$($cluster.name)-$dateString.csv")
"Job Name,Environment,Origination,Policy Name,Object Name,Last Run,Status,Logical Size $unit,Data Read $unit,Data Written $unit,Data Replicated $unit" | Out-File -FilePath $outputfile

if($localOnly){
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&includeLastRunInfo=true"
}else{
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true"
}

$policies = api get -v2 "data-protect/policies?includeTenants=true&excludeLinkedPolicies=false"

$o365Sources = api get protectionSources?environments=kO365
$o365Users = ($o365Sources.nodes | Where-Object {$_.protectionSource.office365ProtectionSource.type -eq 'kUsers'}).nodes | Select-Object -Property @{l='id'; e={$_.protectionSource.id}}, @{l='smtpAddress'; e={$_.protectionSource.office365ProtectionSource.primarySMTPAddress}}
$o365Index = @{}
$o365Users | ForEach-Object {
    $o365Index[$_.id] = $_.smtpAddress
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    "{0}" -f $job.name
    $lastRun = api get -v2 "data-protect/protection-groups/$($job.id)/runs/$($job.lastRun.id)?includeObjectDetails=true"
    $policy = $policies.policies | Where-Object id -eq $job.policyId
    foreach($entity in $lastRun.objects | Sort-Object -Property {$_.object.name}){
        $objectName = $entity.object.name
        if($entity.object.environment -eq 'kO365' -and $entity.object.objectType -eq 'kUser'){
            $altObjectName = $o365Index[$entity.object.id]
            if($altObjectName -and $altObjectName -ne ''){
                $objectName = $altObjectName
            }
        }
        if($entity.object.environment -eq 'kO365' -and $entity.object.objectType -eq 'kSite'){
            $objectName = "$objectName ($($entity.object.sharepointSiteSummary.siteWebUrl))"
        }
        if($job.isActive -eq $false){
            $origination = 'replicated'
            $startTimeUsecs = $lastRun.originalBackupInfo.startTimeUsecs
            $logicalSize = $entity.originalBackupInfo.snapshotInfo.stats.logicalSizeBytes
            $localRead = $entity.originalBackupInfo.snapshotInfo.stats.bytesRead
            $localWritten = $entity.originalBackupInfo.snapshotInfo.stats.bytesWritten
            $status = $entity.originalBackupInfo.snapshotInfo.status.Substring(1)
        }else{
            $origination = 'local'
            $startTimeUsecs = $lastRun.localBackupInfo.startTimeUsecs
            $logicalSize = $entity.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes
            $localRead = $entity.localSnapshotInfo.snapshotInfo.stats.bytesRead
            $localWritten = $entity.localSnapshotInfo.snapshotInfo.stats.bytesWritten
            $status = $entity.localSnapshotInfo.snapshotInfo.status.Substring(1)
        }
        $replicationTransferred = $entity.replicationInfo.replicationTargetResults.stats.physicalBytesTransferred

        "    {0}" -f $objectName
        "{0},{1},{2},{3},{4},{5},{6},""{7}"",""{8}"",""{9}"",""{10}""" -f $job.name, $job.environment.Substring(1) ,$origination, $policy.name, $objectName, (usecsToDate $startTimeUsecs), $status, (toUnits $logicalSize), (toUnits $localRead), (toUnits $localWritten), (toUnits $replicationTransferred) | Out-File -FilePath $outputfile -Append
    }
}

"Output saved to $outputfile"
