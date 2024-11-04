# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$tenant,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][string]$orgName,
    [Parameter()][string]$vdcName,
    [Parameter()][string]$vappName,
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalProtectionSlaTimeMins = 60,
    [Parameter()][int]$fullProtectionSlaTimeMins = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain', #storage domain you want the new job to write to
    [Parameter()][string]$policyName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -tenant $tenant

# find protection source
$sources = api get "protectionSources" | Where-Object {$_.protectionSource.environment -eq 'kVMware' -and 
                                                                              $_.protectionSource.vmWareProtectionSource.type -eq 'kvCloudDirector' -and 
                                                                              $_.protectionSource.name -eq $sourceName}
if(!$sources){
    Write-Host "Protection source $sourceName not found" -ForegroundColor Yellow
    exit 1
}

$source = api get "protectionSources?environments=kVMware&includeSystemVApps=true&includeVMFolders=true&id=$($sources.protectionSource.id)&allUnderHierarchy=true"

# find org
$org = $source.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -eq 'kOrganization' -and 
                                     $_.protectionSource.name -eq $orgName}
if(!$org){
    Write-Host "Org $orgName not found" -ForegroundColor Yellow
    exit 1
}

# find vdc
$vdc = $org.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -eq 'kVirtualDatacenter' -and
                                  $_.protectionSource.name -eq $vdcName}
if(!$vdc){
    Write-Host "VDC $vdcName not found" -ForegroundColor Yellow
    exit 1
}

# find vapp
$vapp = $vdc.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -eq 'kVirtualApp' -and 
                                   $_.protectionSource.name -eq $vappName}
if(!$vapp){
    Write-Host "vApp $vappName not found" -ForegroundColor Yellow
    exit 1
}

$job = api get protectionJobs | Where-Object {$_.name -eq $jobName}
if($job){
    if($job.parentSourceId -ne $source.protectionSource.id){
        Write-Host "Job $jobName uses a different protection source" -ForegroundColor Yellow
        exit 1
    }
    $job.sourceIds += $vapp.protectionSource.id
    $job.sourceIds = @($job.sourceIds | Sort-Object -Unique)

    "Adding vapp $vappName to protection job $($job.name)..."
    $null = api put "protectionJobs/$($job.id)" $job
}else{
    # get policy
    if(!$policyName){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit 1
    }else{
        $policy = api get protectionPolicies | Where-Object name -eq $policyName
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

    $newJob = @{
        "name"                   = $jobName;
        "environment"            = "kVMware";
        "policyId"               = $policy.id;
        "viewBoxId"              = $viewBox.id;
        "parentSourceId"         = $source.protectionSource.id;
        "sourceIds"              = @(
            $vapp.protectionSource.id
        );
        "startTime"              = @{
            "hour"   = [int]$hour;
            "minute" = [int]$minute
        };
        "timezone"               = $timeZone;
        "priority"               = "kLow";
        "indexingPolicy"         = @{
            "disableIndexing" = $false;
            "allowPrefixes"   = @(
                "/"
            );
            "denyPrefixes"    = @(
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
                "/grub2"
            )
        };
        "LeverageSanTransport"   = $null;
    }
    "Adding vapp $vappName to protection job $($job.name)..."
    $null = api post protectionJobs $newJob
}
