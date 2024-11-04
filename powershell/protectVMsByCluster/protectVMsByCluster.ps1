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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$jobName,  # job name
    [Parameter(Mandatory = $True)][string]$vCenterName,  # vcenter source name
    [Parameter(Mandatory = $True)][string]$dataCenter,  # name of vSphere data center
    [Parameter(Mandatory = $True)][array]$computeResource,  # name of compute resource to protect
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

function getObject($objectName, $sources, $objectType=$null){
    $global:_object = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            if(! $objectType -or $obj.protectionSource.vmWareProtectionSource.type -eq $objectType){
                $global:_object = $obj
                break
            }
        }
        if($obj.name -eq $objectName){
            if(! $objectType -or $obj.protectionSource.vmWareProtectionSource.type -eq $objectType){
                $global:_object = $obj
                break
            }
        }        
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object){
                    get_nodes $node
                }
            }
        }
    }
    
    foreach($source in $sources){
        if($null -eq $global:_object){
            get_nodes $source
        }
    }
    return $global:_object
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

# find specified vcenter
$vCenter = api get "protectionSources/rootNodes?environments=kVMware" | Where-Object {$_.protectionSource.name -eq $vCenterName}
if(!$vCenter){
    Write-Host "vCenter $vCenterName not found!" -ForegroundColor Yellow
    exit 1
}

$vCenter = api get "protectionSources?environments=kVMware&id=$($vCenter.protectionSource.id)&excludeTypes=kVirtualMachine,kTagCategory,kTag" | Where-Object {$_.protectionSource.name -eq $vCenterName}
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
    if(! $noStorageDomain){
        $job["storageDomainId"] = $viewBox.id;
    }  
}

$addedObjects = $false

$dc = getObject $dataCenter $vCenter 'kDatacenter'
if(! $dc){
    Write-Host "Data center $dataCenter not found" -ForegroundColor Yellow
    exit
}

foreach($vscluster in $computeResource){
    $clus = $null
    $clus = getObject $vscluster $dc
    if($clus){
        $newVMobject = @{
            'excludeDisks' = $null;
            'id' = $clus.protectionSource.id;
            'name' = $clus.protectionSource.name;
            'isAutoprotected' = $false
        }
        $job.vmwareParams.objects = @($job.vmwareParams.objects + $newVMobject)
        $addedObjects = $True
        Write-Host "Protecting $($clus.protectionSource.name)"
    }else{
        Write-Host "$vscluster not found" -ForegroundColor Yellow
    }
}

if($addedObjects -eq $false){
    Write-Host "No objects protected" -ForegroundColor Yellow
    exit
}

if($newJob){
    "Creating protection job $jobName"
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    "Updating protection job $($job.name)"
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
