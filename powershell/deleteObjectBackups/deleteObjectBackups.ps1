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

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}
$vms = @(gatherList -Param $objectName -FilePath $objectList -Name 'objects' -Required $False)

if($objectMatch){
    $search = api get "/searchvms?vmName=*$($objectMatch)*"
    if(@($search.vms).Count -gt 0){
        $vms = @($vms + $search.vms.vmDocument.objectName | Sort-Object -Unique)
    }
}

if(@($vms).Count -eq 0){
    Write-Host "No servers specified" -ForegroundColor Yellow
    exit
}

# logging
$runDate = get-date -UFormat %Y-%m-%d_%H-%M-%S
$logfile = Join-Path -Path $PSScriptRoot -ChildPath "expungeVMLog-$runDate.txt"

function log($text){
    "$text" | Tee-Object -FilePath $logfile -Append
}

log "- Started at $(get-date) -------`n"

# display run mode
if($delete){
    log "----------------------------------"
    log "  *PERMANENT DELETE MODE*         "
    log "  - selection will be deleted!!!"
    log "  - logging to $logfile"
    log "  - press CTRL-C to exit"
    log "----------------------------------`n"
}else {
    log "--------------------------"
    log "  *TEST RUN MODE*"
    log "  - not deleting"
    log "  - logging to $logfile"
    log "--------------------------`n"
}

foreach($serverName in $vms){
    $search = api get "/searchvms?vmName=$serverName&toTimeUsecs=$(timeAgo $olderThan days)"
    $objects = $search.vms | Where-Object {$_.vmDocument.objectName -eq $serverName}

    foreach($object in $objects){
        $jobUid = $object.vmDocument.objectId.jobUid
        if($jobName -and $jobName -ne $object.vmDocument.jobName){
            continue
        }
        foreach($version in $object.vmDocument.versions){
            if('1' -notin $version.replicaInfo.replicaVec.target.type){
                continue
            }
            $runStartTimeUsecs = $version.instanceId.jobStartTimeUsecs
            if($runStartTimeUsecs -gt $(timeAgo $olderThan days)){
                continue
            }
            if($delete){
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
                                "clusterId" = [int64]$jobUid.clusterId;
                                "clusterIncarnationId" = [int64]$jobUid.clusterIncarnationId;
                                "id" = [int64]$jobUid.objectId
                            };
                            "runStartTimeUsecs" = $runStartTimeUsecs;
                            "sourceIds" = @(
                                $object.vmDocument.objectId.entity.id
                            )
                        }
                    )
                }
                log "Deleting $serverName from $($object.vmDocument.jobName) ($(usecsToDate $runStartTimeUsecs))"
                $null = api put protectionRuns $deleteObjectParams
            }else{
                log "Would delete $serverName from $($object.vmDocument.jobName) ($(usecsToDate $runStartTimeUsecs))"
            }
        }
    }
}
