### usage: ./protectVMs.ps1 -vip bseltzve01 -username admin -jobName 'vm backup' -vmName mongodb

### process commandline arguments
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
    [Parameter()][array]$vmName,  # name of VM to protect
    [Parameter()][string]$vmList = '',  # text file of vm names
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add VM to
    [Parameter()][string]$vCenterName,  # vcenter source name
    [Parameter()][array]$excludeDisk,
    [Parameter()][array]$includeDisk,
    [Parameter()][switch]$includeFirstDiskOnly,
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter()][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD', 'kBackupAll')][string]$qosPolicy = 'kBackupHDD',
    [Parameter()][switch]$disableIndexing,
    [Parameter()][switch]$clear
)

# gather list of servers to add to job
$vmsToAdd = @()
foreach($v in $vmName){
    $vmsToAdd += $v
}
if ('' -ne $vmList){
    if(Test-Path -Path $vmList -PathType Leaf){
        $servers = Get-Content $vmList
        foreach($server in $servers){
            $vmsToAdd += [string]$server
        }
    }else{
        Write-Host "VM list $vmList not found!" -ForegroundColor Yellow
        exit
    }
}
if($vmsToAdd.Count -eq 0){
    Write-Host "No VMs to add" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# validate exclude disks
foreach($disk in $excludeDisk){
    if($disk -notmatch '([0-9]|[0-9][0-9]):([0-9]|[0-9][0-9])'){
        Write-Host "excludeDisk must be in the format busNumber:unitNumber - e.g. 0:1" -ForegroundColor Yellow
        exit
    }
}

# validate include disks
foreach($disk in $includeDisk){
    if($disk -notmatch '([0-9]|[0-9][0-9]):([0-9]|[0-9][0-9])'){
        Write-Host "includeDisk must be in the format busNumber:unitNumber - e.g. 0:1" -ForegroundColor Yellow
        exit
    }
}

$controllerType = @{'SCSI' = 'kScsi'; 'IDE' = 'kIde'; 'SATA' = 'kSata'}

# get the protectionJob
$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}

if($job){

    # existing protection job
    $newJob = $false
    if($clear){
        $job.vmwareParams.objects = @()
    }
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
        $vCenter = api get protectionSources?environments=kVMware | Where-Object {$_.protectionSource.name -eq $vCenterName}
        if(!$vCenter){
            Write-Host "vCenter $vCenterName not found!" -ForegroundColor Yellow
            exit
        }
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

foreach($vmName in $vmsToAdd){
    $vm = api get protectionSources/virtualMachines?vCenterId=$($job.vmwareParams.sourceId) | Where-Object {$_.name -ieq $vmName}
    if(!$vm){
        Write-Host "VM $vmName not found!" -ForegroundColor Yellow
    }else{
        write-host "    adding $vmName"
        $newVMobject = $job.vmwareParams.objects | Where-Object {$_.id -eq $vm.id}
        $excludedDisks = @()
        if(!$newVMobject){
            $newVMobject = @{
                'excludeDisks' = $null;
                'id' = $vm.id;
                'name' = $vm.name;
                'isAutoprotected' = $false
            }
        }
        if($newVMobject.excludeDisks){
            $excludedDisks = @()
        }
        if($excludeDisk.Count -gt 0 -or $includeDisk.Count -gt 0 -or $includeFirstDiskOnly){
            $vm = api get protectionSources/objects/$($vm.id)
            $vdisks = $vm.vmWareProtectionSource.virtualDisks
            foreach($vdisk in $vdisks){
                $disk = "{0}:{1}" -f $vdisk.busNumber, $vdisk.unitNumber
                # exclude if not the fist disk
                if($includeFirstDiskOnly -and $disk -ne '0:0'){
                    $excludedDisks = @($excludedDisks + @{
                        "controllerType" = $controllerType[$vdisk.controllerType];
                        "busNumber" = $vdisk.busNumber;
                        "unitNumber" = $vdisk.unitNumber
                    })
                # exclude if not explicitly included
                }elseif($includeDisk.Count -gt 0 -and $disk -notin $includeDisk){
                    $excludedDisks = @($excludedDisks + @{
                        "controllerType" = $controllerType[$vdisk.controllerType];
                        "busNumber" = $vdisk.busNumber;
                        "unitNumber" = $vdisk.unitNumber
                    })
                # exclude if explicitly excluded
                }elseif($disk -in $excludeDisk){
                    $excludedDisks = @($excludedDisks + @{
                        "controllerType" = $controllerType[$vdisk.controllerType];
                        "busNumber" = $vdisk.busNumber;
                        "unitNumber" = $vdisk.unitNumber
                    })
                }
            }
        }

        if($excludedDisks.count -gt 0){
            $newVMobject.excludeDisks = @($excludedDisks)
        }
        $job.vmwareParams.objects = @(@($job.vmwareParams.objects | Where-Object {$_.id -ne $vm.id}) + $newVMobject)
    }
}

if($newJob){
    "Creating protection job $jobName"
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    "Updating protection job $($job.name)"
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
