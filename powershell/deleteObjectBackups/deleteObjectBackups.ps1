# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][array]$objectName,  # optional names of vms to expunge (comma separated)
    [Parameter()][string]$objectList = '',  # optional textfile of vms to expunge (one per line)
    [Parameter()][string]$objectMatch,
    [Parameter()][string]$jobName,
    [Parameter()][string]$tenantId = $null,
    [Parameter()][int]$olderThan = 0,
    [Parameter()][switch]$delete # delete or just a test run
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -tenantId $tenantId.ToUpper()

# gather list of vms to expunge

$vms = @()
foreach($v in $objectName){
    $vms += $v
}
if ('' -ne $objectList){
    if(Test-Path -Path $objectList -PathType Leaf){
        $vmfile = Get-Content $objectList
        foreach($v in $vmfile){
            $vms += [string]$v
        }
    }else{
        Write-Warning "VM list $objectList not found!"
        exit
    }
}

if($objectMatch){
    $search = api get "/searchvms?vmName=*$($objectMatch)*"
    if($search){
        $vms = @($vms + $search.vms.vmDocument.objectName)
    }
}

# logging 

$runDate = get-date -UFormat %Y-%m-%d_%H-%M-%S
$logfile = Join-Path -Path $PSScriptRoot -ChildPath "expungeVMLog-$runDate.txt"

function log($text){
    "$text" | Tee-Object -FilePath $logfile -Append
}

log "- Started at $(get-date) -------`n"

# display run mode

if ($delete) {
    log "----------------------------------"
    log "  *PERMANENT DELETE MODE*         "
    log "  - selection will be deleted!!!"
    log "  - logging to $logfile"
    log "  - press CTRL-C to exit"
    log "----------------------------------`n"
}
else {
    log "--------------------------"
    log "  *TEST RUN MODE*"
    log "  - not deleting"
    log "  - logging to $logfile"
    log "--------------------------`n"
}

$olderThanUsecs = dateToUsecs (get-date).AddDays(-$olderThan)
$jobs = api get protectionJobs

foreach($serverName in $vms){
    $search = api get /searchvms?vmName=$serverName
    $objects = $search.vms | Where-Object { $_.vmDocument.objectName -eq $serverName }
    foreach($object in $objects){
        $sourceId = $object.vmDocument.objectId.entity.id
        $protectionGroupName = $object.vmDocument.jobName
        $protectionGroupId = $object.vmDocument.objectId.jobId
        if(!$jobName -or $jobName -eq $protectionGroupName){
            $job = $jobs | Where-Object id -eq $protectionGroupId
            foreach($version in $object.vmDocument.versions){
                $runStartTimeUsecs = $version.instanceId.jobStartTimeUsecs
                if($runStartTimeUsecs -lt $olderThanUsecs -and '1' -in $version.replicaInfo.replicaVec.target.type){
                    $run = api get "/backupjobruns?id=$($job.id)&ExactMatchStartTimeUsecs=$runStartTimeUsecs"
                    $deleteObjectParams = @{
                        "jobRuns" = @(
                            @{
                                "copyRunTargets" = @(
                                    @{
                                        "daysToKeep" = 0;
                                        "type" = "kLocal"
                                    }
                                );
                                "jobUid" = @{
                                    "clusterId" = $object.vmDocument.objectId.jobUid.clusterId;
                                    "clusterIncarnationId" = $object.vmDocument.objectId.jobUid.clusterIncarnationId;
                                    "id" = $object.vmDocument.objectId.jobUid.objectId
                                };
                                "runStartTimeUsecs" = $runStartTimeUsecs;
                                "sourceIds" = @(
                                    $sourceId
                                )
                            }
                        )
                    }
                    if($delete){
                        log "Deleting $serverName from $protectionGroupName ($(usecsToDate $runStartTimeUsecs))"
                        $null = api put protectionRuns $deleteObjectParams
                    }else{
                        log "Would delete $serverName from $protectionGroupName ($(usecsToDate $runStartTimeUsecs))"
                    }
                }
            }
        }
    }
}

