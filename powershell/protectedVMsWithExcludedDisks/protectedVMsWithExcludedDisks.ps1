[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

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