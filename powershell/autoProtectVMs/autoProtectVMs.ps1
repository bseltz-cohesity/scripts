### process commandline arguments
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
    [Parameter()][array]$objectName,  # name of container to protect
    [Parameter()][string]$objectList = '',  # text file of containers
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add VM to
    [Parameter()][string]$vCenterName,  # vcenter source name
    [Parameter(Mandatory = $True)][string]$dataCenter,
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter()][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD')][string]$qosPolicy = 'kBackupHDD',
    [Parameter()][switch]$disableIndexing
)

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

$objectNames = @(gatherList -Param $objectName -FilePath $objectList -Name 'containers' -Required $True)

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

# get the protectionJob
$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}

if($job){

    # existing protection job
    $newJob = $false
    $vCenter = api get "protectionSources?environments=kVMware&includeVMFolders=true&excludeTypes=kResourcePool,kVirtualMachine,kVirtualApp,kTagCategory,kTag&id=$($job.vmwareParams.sourceId)"

}else{

    # new protection group
    $newJob = $True

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

    if(!$vCenterName){
        Write-Host "-vCenterName required" -ForegroundColor Yellow
        exit
    }else{
        $vCenter = api get "protectionSources/rootNodes?environments=kVMware" | Where-Object {$_.protectionSource.name -eq $vCenterName}
        if(!$vCenter){
            Write-Host "vCenter $vCenterName not found!" -ForegroundColor Yellow
            exit
        }
        $vCenter = api get "protectionSources?environments=kVMware&includeVMFolders=true&excludeTypes=kResourcePool,kVirtualMachine,kVirtualApp,kTagCategory,kTag" | Where-Object {$_.protectionSource.name -eq $vCenterName}
    }

    # get policy
    if(!$policyName){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit
    }else{
        $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
        if(!$policy){
            Write-Host "Policy $policyName not found" -ForegroundColor Yellow
            exit
        }
    }
    
    # get storageDomain
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
        "storageDomainId"  = $viewBox.id;
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
            "sourceId"                          = $vCenter.protectionSource.id
            "objects"                           = @();
            "excludeObjectIds"                  = @();
            "appConsistentSnapshot"             = $false;
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

# select VM folder
$vmfolderId = @{}
$vcRoot = "$($vCenter.protectionSource.name)/Datacenters/"

function walkVMFolders($node, $parent=$null, $fullPath=''){
    $fullPath = "{0}/{1}" -f $fullPath, $node.protectionSource.name
    $relativePath = $fullPath.split($vcRoot, 2)[1]
    if($relativePath){
        if($relativePath -match "$dataCenter/host/"){
            $relativePath = $relativePath.split("$dataCenter/host/", 2)[1]
        }
        if($relativePath -match "$dataCenter/vm/"){
            $relativePath = $relativePath.split("$dataCenter/vm/", 2)[1]
        }
        $vmFolderId[$relativePath] = $node.protectionSource.id
        if($node.protectionSource.name -notin $vmFolderId.Keys){
            $vmFolderId[$node.protectionSource.name] = $node.protectionSource.id
        }
    }
    if($node.PSObject.Properties['nodes']){
        foreach($subnode in $node.nodes){
            walkVMFolders $subnode $node $fullPath
        }
    }
}

walkVMFolders $vCenter

$objectsAdded = 0
foreach($container in $objectNames){
    if(!($container -in $vmFolderId.Keys)){
        Write-Host "$container not found" -ForegroundColor Yellow
    }else{
        $objectId = $vmFolderId[$container]
        $job.vmwareParams.objects = @(($job.vmwareParams.objects | Where-Object id -ne $objectId) + @{
            'excludeDisks' = $null;
            'id' = $objectId;
            'name' = ($container -split '/')[-1];
            'isAutoprotected' = $false
        })
        $objectsAdded += 1
    }
}

if($objectsAdded -gt 0){
    if($newJob){
        "Creating protection job $jobName"
        $null = api post -v2 "data-protect/protection-groups" $job
    }else{
        "Updating protection job $($job.name)"
        $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
    }
}else{
    Write-Host "No objects added" -ForegroundColor Yellow
}
