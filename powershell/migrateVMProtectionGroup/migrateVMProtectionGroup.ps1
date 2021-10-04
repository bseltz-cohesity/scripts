# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$sourceUser,
    [Parameter()][string]$sourceDomain = 'local',
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter(Mandatory = $True)][string]$targetUser,
    [Parameter()][string]$targetDomain = 'local',
    [Parameter(Mandatory = $True)][string]$jobName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain

$job = (api get -v2 'data-protect/protection-groups').protectionGroups | Where-Object name -eq $jobName

if($job){
    $oldPolicy = (api get -v2 data-protect/policies).policies | Where-Object id -eq $job.policyId
    $oldStorageDomain = api get viewBoxes | Where-Object id -eq $job.storageDomainId
    # Read-Host -Prompt "switch clusters if on RT (hit enter if already connected)"
    apiauth -vip $targetCluster -username $targetUser -domain $targetDomain
    # update vCenter ID
    $newVCenter = api get protectionSources?environments=kVMware | Where-Object {$_.protectionSource.name -eq $job.vmwareParams.sourceName}
    $job.vmwareParams.sourceId = $newVCenter.protectionSource.id
    # update storage domain id
    $newStorageDomain = api get viewBoxes | Where-Object name -eq $oldStorageDomain.name
    $job.storageDomainId = $newStorageDomain.id
    # update policy id
    $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $oldPolicy.name
    $job.policyId = $newPolicy.id
    # update object IDs
    foreach($vm in $job.vmwareParams.objects){
        $newVM = api get "protectionSources/virtualMachines?vCenterId=$($job.vmwareParams.sourceId)&names=$($vm.name)"
        $vm.id = $newVM.id
    }
    api post -v2 data-protect/protection-groups $job
}
