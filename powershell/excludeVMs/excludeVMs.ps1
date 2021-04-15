### usage: ./excludeVMs.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'vm backup' -vmName mongodb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][array]$vmName,  # name of VM to protect
    [Parameter()][string]$vmList = '',  # text file of vm names
    [Parameter(Mandatory = $True)][string]$jobName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get the protectionJob
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true"
$job = $jobs.protectionGroups | Where-Object name -eq $jobName

if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

# gather list of servers to add to job
$vmsToExclude = @()
foreach($v in $vmName){
    $vmsToExclude += $v
}
if ('' -ne $vmList){
    if(Test-Path -Path $vmList -PathType Leaf){
        $servers = Get-Content $vmList
        foreach($server in $servers){
            $vmsToExclude += [string]$server
        }
    }else{
        Write-Host "VM list $vmList not found!" -ForegroundColor Yellow
        exit
    }
}
if($vmsToExclude.Count -eq 0){
    Write-Host "No VMs to add" -ForegroundColor Yellow
    exit
}

$vmsAdded = $false

foreach($vmName in $vmsToExclude){
    ### get the VM
    $vm = api get protectionSources/virtualMachines?vCenterId=$($job.vmwareParams.sourceId) | Where-Object {$_.name -ieq $vmName}
    if(!$vm){
        Write-Host "VM $vmName not found!" -ForegroundColor Yellow
    }else{
        $vmsAdded = $True
        Write-Host "Excluding $vmName"
        if(!$job.vmwareParams.PSObject.Properties['excludeObjectIds']){
            setApiProperty -object $job.vmwareParams -name 'excludeObjectIds' -value @($vm.id)
        }else{
            $job.vmwareParams.excludeObjectIds = @($job.vmwareParams.excludeObjectIds + $vm.id)
        }
    } 
}

### update the job
if($vmsAdded){
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
