### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmList,
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',
    [Parameter()][string]$policyName,
    [Parameter()][switch]$paused,
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD')][string]$qosPolicy = 'kBackupHDD'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

function getObjectId($objectName, $source){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            $global:_object_id = $obj.protectionSource.id
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
    get_nodes $source
    return $global:_object_id
}

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

$vmNames = @(gatherList -Param $vmName -FilePath $vmList -Name 'vms' -Required $True)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# get registered AWS source
$source = api get "protectionSources?environments=kHyperV" | Where-Object {$_.protectionSource.name -eq $sourceName}
if(!$source){
    Write-Host "Hyper-V protection source '$sourceName' not found" -ForegroundColor Yellow
    exit
}

$sourceId = $source.protectionSource.id
$sourceName = $source.protectionSource.name

# get the protectionJob
Write-Host "`nLooking for existing protection job..."
$job = (api get -v2 "data-protect/protection-groups?environments=kAWS").protectionGroups | Where-Object {$_.name -eq $jobName}

if(! $job){

    $newJob = $True

    if($paused){
        $isPaused = $True
    }else{
        $isPaused = $false
    }

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit
    }
    
    if(! $policyName){
        Write-Host "-policyName required to create new protection job" -ForegroundColor Yellow
        exit
    }
    $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
    if(!$policy){
        Write-Host "Policy $policyName not found" -ForegroundColor Yellow
        exit
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

    $job = @{
        "name" = $jobName;
        "policyId" = $policy.id;
        "priority" = "kMedium";
        "storageDomainId" = $viewBox.id;
        "description" = "";
        "startTime" = @{
            "hour"     = [int]$hour;
            "minute"   = [int]$minute;
            "timeZone" = $timeZone
        };
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "sla" = @(
            @{
                "backupRunType" = "kFull";
                "slaMinutes"    = $fullSlaMinutes
            };
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes"    = $incrementalSlaMinutes
            }
        );
        "qosPolicy" = $qosPolicy;
        "abortInBlackouts" = $false;
        "isActive" = $True;
        "isPaused" = $isPaused;
        "environment" = "kHyperV";
        "permissions" = @();
        "missingEntities" = $null;
        "hypervParams" = @{
            "protectionType" = "kAuto";
            "objects" = @();
            "excludeObjectIds" = $null;
            "vmTagIds" = $null;
            "excludeVmTagIds" = $null;
            "appConsistentSnapshot" = $false;
            "fallbackToCrashConsistentSnapshot" = $true;
            "indexingPolicy" = @{
                "enableIndexing" = $true;
                "includePaths" = @(
                    "/"
                );
                "excludePaths" = @(
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
                    "/opt";
                    "/splunk"
                )
            };
            "sourceId" = $sourceId;
            "sourceName" = $sourceName
        }
    }
}else{
    $newJob = $false
    if($job.hypervParams.sourceId -ne $sourceId){
        Write-Host "Protection job '$jobName' uses a different registered Hyper-V protection source" -ForegroundColor Yellow
        exit
    }
}

if($newJob -eq $True){
    Write-Host "`nCreating protection job '$jobName'...`n"
}else{
    Write-Host "`nUpdating protection job '$jobName'...`n"
}

foreach($vm in $vmnames){
    $vmid = getObjectId $vm $source
    if($vmid){
        Write-Host "    Protecting '$vm'"
        $existingObject = $job.hypervParams.objects | Where-Object {$_.id -eq $vmid}
        if(! $existingObject){
            $job.hypervParams.objects = @($job.hypervParams.objects + @{"id" = $vmid; "name" = $vm})
        }
    }else{
        Write-Host "    VM '$vm' not found" -ForegroundColor Yellow
    }
}

if($newJob -eq $True){
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    $null = api put "data-protect/protection-groups/$($job.id)" $job -v2
}
Write-Host ""
