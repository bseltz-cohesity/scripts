# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$tenant,  # org name
    [Parameter(Mandatory = $True)][string]$jobName,  # job name
    [Parameter(Mandatory = $True)][string]$vCenterName,  # vcenter source name
    [Parameter()][object]$includeTag,  # tag name or list of tags to exclude
    [Parameter()][object]$excludeTag,  # tag name or list of tags to exclude
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter()][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD')][string]$qosPolicy = 'kBackupHDD',
    [Parameter()][switch]$disableIndexing,
    [Parameter()][switch]$appConsistent,
    [Parameter()][switch]$noStorageDomain
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -tenant $tenant

function getObjectId($objectName, $sources){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            $global:_object_id = $obj.protectionSource.id
            break
        }
        if($obj.name -eq $objectName){
            $global:_object_id = $obj.id
            break
        }        
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object_id){
                    get_nodes $node
                }
            }
        }
    }
    
    foreach($source in $sources){
        if($null -eq $global:_object_id){
            get_nodes $source
        }
    }
    return $global:_object_id
}

if($paused){
    $isPaused = $True
}else{
    $isPaused = $false
}

if($disableIndexing){
    $enableIndexing = $false
}else{
    $enableIndexing = $True
}

if($appConsistent){
    $appConsistency = $True
}else{
    $appConsistency = $false
}

$vCenter = api get protectionSources?environments=kVMware | Where-Object {$_.protectionSource.name -eq $vCenterName}
if(!$vCenter){
    Write-Host "vCenter $vCenterName not found!" -ForegroundColor Yellow
    exit 1
}

$includeTagIds = @()
foreach($tag in $includeTag){
    $tagId = getObjectId $tag $vCenter
    if($tagId){
        $includeTagIds += $tagId
    }else{
        Write-Host "tag '$tag' not found" -ForegroundColor Yellow
        exit 1
    }
}

$excludeTagIds = @()
foreach($tag in $excludeTag){
    $tagId = getObjectId $tag $vCenter
    if($tagId){
        $excludeTagIds += $tagId
    }else{
        Write-Host "tag '$tag' not found" -ForegroundColor Yellow
        exit 1
    }
}

if($excludeTagIds.Count -eq 0 -and $includeTagIds.Count -eq 0){
    Write-Host "-includeTag or -excludeTag required" -ForegroundColor Yellow
    exit 1
}

$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}

if($job){

    # existing protection job
    $newJob = $false

    if($job.vmwareParams.sourceId -ne $vCenter.protectionSource.id){
        Write-Host "Job $jobName uses a different vCenter, please use a new or different job" -ForegroundColor Yellow
        exit 1
    }

}else{

    # new protection group
    $newJob = $True
    if($includeTagIds.Count -eq 0){
        Write-Host "No includeTags found" -ForegroundColor Yellow
        exit 1
    }

    # get policy
    if(!$policyName){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit 1
    }else{
        $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
        if(!$policy){
            Write-Host "Policy $policyName not found" -ForegroundColor Yellow
            exit 1
        }
    }
    
    # get storageDomain
    if(! $noStorageDomain){
        $viewBoxes = api get viewBoxes
        if($viewBoxes -is [array]){
                $viewBox = $viewBoxes | Where-Object { $_.name -ieq $storageDomainName }
                if (!$viewBox) { 
                    write-host "Storage domain $storageDomainName not Found" -ForegroundColor Yellow
                    exit
                }
        }else{
            $viewBox = $viewBoxes[0]
        }
    }


    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit
    }

    $job = @{
        "name"             = $jobName;
        "environment"      = "kVMware";
        "isPaused"         = $isPaused;
        "policyId"         = $policy.id;
        "priority"         = "kMedium";
        "description"      = "";
        "startTime"        = @{
            "hour"     = [int]$hour;
            "minute"   = [int]$minute;
            "timeZone" = $timeZone
        };
        "abortInBlackouts" = $false;
        "alertPolicy"      = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets"    = @()
        };
        "sla"              = @(
            @{
                "backupRunType" = "kFull";
                "slaMinutes"    = $fullSlaMinutes
            };
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes"    = $incrementalSlaMinutes
            }
        );
        "qosPolicy"        = $qosPolicy;
        "vmwareParams"     = @{
            "objects"                           = @();
            "excludeObjectIds"                  = @();
            "appConsistentSnapshot"             = $appConsistency;
            "fallbackToCrashConsistentSnapshot" = $false;
            "skipPhysicalRDMDisks"              = $false;
            "globalExcludeDisks"                = @();
            "leverageHyperflexSnapshots"        = $false;
            "leverageStorageSnapshots"          = $false;
            "cloudMigration"                    = $false;
            "indexingPolicy"                    = @{
                "enableIndexing" = $enableIndexing;
                "includePaths"   = @(
                    "/"
                );
                "excludePaths"   = @(
                    '/$Recycle.Bin';
                    "/Windows";
                    "/Program Files";
                    "/Program Files (x86)";
                    "/ProgramData";
                    "/System Volume Information";
                    "/Users/*/AppData";
                    "/Recovery";
                    "/var";
                    "/usr";
                    "/sys";
                    "/proc";
                    "/lib";
                    "/grub";
                    "/grub2";
                    "/opt/splunk";
                    "/splunk"
                )
            }
        }
    }     
}

if(! $noStorageDomain){
    $job["storageDomainId"] = $viewBox.id;
}

# include tags
if($includeTagIds.Count -gt 0){
    if($newJob){
        $job.vmwareParams['vmTagIds'] = @()
    }else{
        if(! $job.vmwareParams.PSObject.Properties['vmTagIds']){
            setApiProperty -object $job.vmwareParams -name 'vmTagIds' -value @()
        }
    }
    $job.vmwareParams.vmTagIds += ,@($includeTagIds)
}

# exclude tags
if($excludeTagIds.Count -gt 0){
    if($newJob){
        $job.vmwareParams['excludeVmTagIds'] = @()
    }else{
        if(! $job.vmwareParams.PSObject.Properties['excludeVmTagIds']){
            setApiProperty -object $job.vmwareParams -name excludeVmTagIds -value @()
        }
    }
    $job.vmwareParams.excludeVmTagIds += ,@($excludeTagIds)
}

if($newJob){
    "Creating protection job $jobName"
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    "Updating protection job $($job.name)"
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
