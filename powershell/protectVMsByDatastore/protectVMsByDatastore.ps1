# process commandline arguments
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
    [Parameter(Mandatory = $True)][string]$jobName,  # job name
    [Parameter(Mandatory = $True)][string]$vCenterName,  # vcenter source name
    [Parameter(Mandatory = $True)][string]$dataStoreName,  # name of datastore to protect
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter()][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD')][string]$qosPolicy = 'kBackupHDD',
    [Parameter()][switch]$disableIndexing
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

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

# find specified vcenter
$vCenter = api get protectionSources/rootNodes?environments=kVMware | Where-Object {$_.protectionSource.name -eq $vCenterName}
if(!$vCenter){
    Write-Host "vCenter $vCenterName not found!" -ForegroundColor Yellow
    exit 1
}

# find unprotected VMs on specified datastore
$vms = api get "protectionSources/virtualMachines?vCenterId=$($vCenter.protectionSource.id)&protected=false" | Where-Object {$_.vmWareProtectionSource.virtualDisks.fileName -match "\[$dataStoreName\]"}
if($vms.Count -eq 0){
    Write-Host "All VMs on datastore $dataStoreName are protected" -ForegroundColor Green
    exit
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

# find specified protection job
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

foreach($vm in $vms | Sort-Object -Property name){
    if($vm.id -notin $job.vmwareParams.objects.id){
        Write-Host "    protecting $($vm.name)"
        $job.vmwareParams.objects += @{
            'excludeDisks' = $null;
            'id' = $vm.id;
            'name' = $vm.name;
            'isAutoprotected' = $false
        }
    }
}

if($newJob){
    "Creating protection job $jobName"
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    "Updating protection job $($job.name)"
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
