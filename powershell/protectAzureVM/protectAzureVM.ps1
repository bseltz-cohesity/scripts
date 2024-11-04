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
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$vmName,  # name of VM to protect
    [Parameter()][string]$vmList = '',  # text file of vm names
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add VM to
    [Parameter(Mandatory = $True)][string]$azureSourceName,  # azure source source name
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter()][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD', 'kBackupAll')][string]$qosPolicy = 'kBackupHDD',
    [Parameter()][ValidateSet('kNative', 'kSnapshotManager')][string]$protectionType = 'kNative',
    [Parameter()][switch]$disableIndexing
)

$azureParamNames = @{'kNative' = 'nativeProtectionTypeParams'; 'kSnapshotManager' = 'snapshotManagerProtectionTypeParams'}
$azureParamName = $azureParamNames[$protectionType]

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

$vmsToAdd = @(gatherList -Param $vmName -FilePath $vmList -Name 'VMs' -Required $True)

function getObject($objectName, $sources, $objectType=$null){
    $global:_object = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            if(! $objectType -or $obj.protectionSource.azureProtectionSourcetype -eq $objectType){
                $global:_object = $obj
                break
            }
        }
        if($obj.name -eq $objectName){
            if(! $objectType -or $obj.protectionSource.azureProtectionSourcetype -eq $objectType){
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

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

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

$azureSource = api get protectionSources?environments=kAzure | Where-Object {$_.protectionSource.name -eq $azureSourceName}
if(!$azureSource){
    Write-Host "azure source $azureSourceName not found!" -ForegroundColor Yellow
    exit
}

# get the protectionJob
$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}

if($job){
    # existing protection job
    $newJob = $false
    $protectionType = $job.azureParams.protectionType
    $azureParamName = $azureParamNames[$protectionType]
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
        "environment"      = "kAzure";
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
        "azureParams"     = @{
            "protectionType" = $protectionType;
            "$azureParamName" = @{
                "objects" = @();
                "excludeObjectIds" = @();
                "vmTagIds" = @();
                "excludeVmTagIds" = @();
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
                }
            }
        }
    }     
}

foreach($vmName in $vmsToAdd){
    $vm = getObject $vmName $azureSource
    if(!$vm){
        Write-Host "VM $vmName not found!" -ForegroundColor Yellow
    }else{
        write-host "    adding $vmName"
        $newVMobject = @{'id' = $vm.protectionSource.id}
        $job.azureParams.$azureParamName.objects = @(@($job.azureParams.$azureParamName.objects | Where-Object {$_.id -ne $vm.protectionSource.id}) + $newVMobject)
    }
}

if($newJob){
    "Creating protection job $jobName"
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    "Updating protection job $($job.name)"
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
