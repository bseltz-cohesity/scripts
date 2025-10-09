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
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
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

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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
    $search = api get "/searchvms?vmName=$serverName&toTimeUsecs=$(timeAgo $olderThan days)"
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
                    if($delete){
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

