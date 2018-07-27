### usage: ./protectVM.ps1 -vip mycluster -username admin -jobName 'vm backup' -vmName mongodb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$vmName, #name of VM to protect
    [Parameter(Mandatory = $True)][string]$jobName #name of the job to add VM to
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

### get the VM
$vm = api get protectionSources/virtualMachines?vCenterId=$($job.parentSourceId) | Where-Object {$_.name -ieq $vmName}
if(!$vm){
    Write-Warning "VM $vmName not found!"
    exit
}

### add the M to the job
if($vm.id -in $job.sourceIds){
    "VM $($vm.name) already in job $($job.name)"
    exit
}
$job.sourceIds += $vm.id

### update the job
"adding $($vm.name) to $($job.name) job"
$updatedJob = api put protectionJobs/$($job.id) $job