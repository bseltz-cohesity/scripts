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
    [Parameter()][string]$clusterName
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

$cluster = api get cluster

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-protectedVMsWithExcludedDisks-$dateString.txt"
"`nProtected VMs with excluded disks:" | Tee-Object -FilePath $outfileName

$vms = api get "protectionSources/virtualMachines?protected=true&allUnderHierarchy=true"
$jobs = api get "protectionJobs?environments=kVMware&allUnderHierarchy=true" | where-object {$_.isDeleted -ne $True -and $_.isActive -ne $False}

foreach($job in $jobs){
    $jobReported = $False
    $sourceSpecialParameters = $job.sourceSpecialParameters | Where-Object {$_.vmwareSpecialParameters.excludedDisks -ne $null }
    foreach($source in $sourceSpecialParameters){
        if($False -eq $jobReported){
            "`n$($job.name)" | Tee-Object -FilePath $outfileName -Append
        }
        $vmName = ($vms | Where-Object id -eq $source.sourceId).name
        "    $vmName" | Tee-Object -FilePath $outfileName -Append
        foreach($excludedDisk in $source.vmwareSpecialParameters.excludedDisks){
            "        {0}({1}:{2})" -f $excludedDisk.controllerType, $excludedDisk.busNumber, $excludedDisk.unitNumber | Tee-Object -FilePath $outfileName -Append
        }
    }
}

"`nOutput written to $outfilename`n"