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

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -gt '6.5.1'){
    Write-Host "This script is for Cohesity versions prior to 6.5.1" -ForegroundColor Yellow
    exit
}

### get the protectionJob
$jobs = api get protectionJobs
$job = $jobs | Where-Object name -eq $jobName

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
    $vm = api get protectionSources/virtualMachines?vCenterId=$($job.parentSourceId) | Where-Object {$_.name -ieq $vmName}
    if(!$vm){
        Write-Host "VM $vmName not found!" -ForegroundColor Yellow
    }else{
        $vmsAdded = $True
        Write-Host "Excluding $vmName"
        if(!$job.PSObject.Properties['excludeSourceIds']){
            setApiProperty -object $job -name 'excludeSourceIds' -value @($vm.id)
        }else{
            $job.excludeSourceIds = @($job.excludeSourceIds + $vm.id) | Sort-Object -Unique
        }
    } 
}

### update the job
if($vmsAdded){
    $null = api put "protectionJobs/$($job.id)" $job
}
