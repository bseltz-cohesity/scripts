### usage: ./protectIsilonShares.ps1 -vip mycluster -username myusername -policyName 'My Policy' -isilon Isilon1

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$isilonName, # name of registered Isilon source
    [Parameter()][string]$shareList = './shares.txt', # file name containing list of shares
    [Parameter(Mandatory = $True)][string]$policyName, # name of protection policy to use
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain', # name of storage domain to store the backups
    [Parameter()][string]$startTime= '22:00' # job start time
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### start time hours and minutes
[int] $startHour, [int] $startMinute = $startTime.split(':')

### find Isilon source
$sources = api get protectionSources?environment=kIsilon | Where-Object { $_.protectionSource.name -eq $isilonName }
if($sources){
    $parentID = $sources[0].protectionSource.id
}else{
    Write-Warning "Protection Source $isilonName not found!"
    exit
}
$isilonSource = api get "protectionSources?allUnderHierarchy=true&id=$parentID"

### find protection policy
$policy = api get protectionPolicies | Where-Object {$_.name -eq $policyName }
if($policy){
   $policyID = $policy.id 
}else{
    Write-Warning "Policy $policyName not found!"
    exit
}

### find storage domain
$viewBox = api get viewBoxes | Where-Object { $_.name -eq $storageDomain }
if($viewBox){
    $viewBoxID = $viewBox.id
}

### protect shares
$shareNames = Get-Content $shareList

foreach ($shareName in $shareNames) {

    $jobName = "$isilonName-$shareName"

    ### find share on Isilon
    $share = $isilonSource.nodes[0].nodes | Where-Object { $_.protectionSource.isilonProtectionSource.mountPoint.smbMountPoints.shareName -eq $shareName }
    if ($share) {
        $shareID = $share.protectionSource.id
    }
    else {
        Write-Warning "Share $shareName not found!"\
        exit
    }

    ### new protection job parameters
    $newJob = @{
        "name"                             = $jobName;
        "environment"                      = "kIsilon";
        "parentSourceId"                   = $parentID;
        "sourceIds"                        = @(
            $shareID
        );
        "priority"                         = "kMedium";
        "alertingPolicy"                   = @(
            "kFailure"
        );
        "alertingConfig"                   = @{
            "emailAddresses" = @()
        };
        "timezone"                         = "America/New_York";
        "incrementalProtectionSlaTimeMins" = 60;
        "fullProtectionSlaTimeMins"        = 120;
        "qosType"                          = "kBackupHDD";
        "environmentParameters"            = @{
            "nasParameters" = @{
                "nasProtocol"     = "kNfs3";
                "continueOnError" = $true
            }
        };
        "isActive"                         = $true;
        "isDeleted"                        = $false;
        "indexingPolicy"                   = @{
            "disableIndexing" = $true
        };
        "policyId"                         = $policyID;
        "viewBoxId"                        = $viewBoxID;
        "startTime"                        = @{
            "hour"   = $startHour;
            "minute" = $startMinute
        }
    }

    ### create protection job
    $result = api post protectionJobs $newJob
    if($result){
        "Creating Job $jobName..."
    }
}