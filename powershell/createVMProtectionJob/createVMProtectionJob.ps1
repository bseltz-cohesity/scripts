### Usage: ./createVMProtectionJob.ps1 -vip mycluster -username admin -jobName myjob -policyName mypolicy -vCenterName vcenter.mydomain.net -startTime '23:05' -vmList ./myvms.txt

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter(Mandatory = $True)][string]$jobName, #Name of the policy to manage
    [Parameter(Mandatory = $True)][string]$policyName,
    [Parameter(Mandatory = $True)][string]$startTime,
    [Parameter(Mandatory = $True)][string]$vCenterName,
    [Parameter(Mandatory = $True)][string]$vmList,
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain'
)

$hours, $minutes = $startTime.split(':')
if(! $hours -and $minutes){
    Write-Warning "invalid start time"
    exit
}

$vmsToProtect = get-content $vmList
if(! $vmsToProtect){
    Write-Warning "No VMs Specified"
    exit
}

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### check for existing job
$job = api get protectionJobs | Where-Object { $_.name -eq $jobName }
if($job){
    Write-Warning "Job $jobName already exists"
    exit
}

### get policyId
$policyId = (api get protectionPolicies | Where-Object { $_.name -eq $policyName }).id
if(! $policyId){
    Write-Warning "Policy $policyName not found"
    exit
}

### get storageDomainId
$storageDomainId = (api get viewBoxes | Where-Object { $_.name -eq $storageDomain }).id
if(! $storageDomainId){
    Write-Warning "Storage Domain $storageDomain not found"
    exit

}

### get vCenter
$vCenter = (api get protectionSources?environment=kVMware | Where-Object { $_.protectionSource.name -eq "$vCenterName"})
if(! $vCenter){
    Write-Warning "Can't find vCenter $vCenter"
    exit
}
$vCenterId = $vCenter.protectionSource.id

### get VMs to protect
$vms = api get protectionSources/virtualMachines?vCenterId=$vCenterId
$myvms = $vms | Where-Object { $_.name -in $vmsToProtect }
$sourceIds = @($myvms.id)

### create protection job
$newJob = @{
    'name' = $jobName;
    'environment' = 'kVMware';
    '_envParams' = @{
        'fallbackToCrashConsistent' = $true
    };
    'parentSourceId' = $vCenterId;
    'sourceIds' = $sourceIds;
    'excludeSourceIds' = @();
    'vmTagIds' = @();
    'excludeVmTagIds' = @();
    'priority' = 'kMedium';
    'alertingPolicy' = @(
        'kFailure'
    );
    'timezone' = 'America/New_York';
    'incrementalProtectionSlaTimeMins' = 60;
    'fullProtectionSlaTimeMins' = 120;
    'qosType' = 'kBackupHDD';
    '_sourceSpecialParametersMap' = @{};
    'isActive' = $true;
    '_supportsAutoProtectExclusion' = $true;
    'sourceSpecialParameters' = @();
    'isDeleted' = $true;
    'environmentParameters' = @{
        'vmwareParameters' = @{
            'fallbackToCrashConsistent' = $true
        }
    };
    '_supportsIndexing' = $false;
    'indexingPolicy' = @{
        'disableIndexing' = $false;
        'allowPrefixes' = @(
            '/'
        );
        'denyPrefixes' = @(
            '/$Recycle.Bin';
            '/Windows';
            '/Program Files';
            '/Program Files (x86)';
            '/ProgramData';
            '/System Volume Information';
            '/Users/*/AppData';
            '/Recovery';
            '/var';
            '/usr';
            '/sys';
            '/proc';
            '/lib';
            '/grub';
            '/grub2'
        )
    };
    '_hasFilePathFilters' = $false;
    '_hasPreScript' = $false;
    '_hasPostScript' = $false;
    '_createRemoteView' = $false;
    'policyId' = $policyId;
    'viewBoxId' = $storageDomainId;
    'startTime' = @{
        'hour' = [int]$hours;
        'minute' = [int]$minutes;
        'second' = 0
    }
}

"creating protection job $jobName..."
$result = api post protectionJobs $newJob

