### usage: ./unprotectVM.ps1 -vip mycluster -username myuser -domain local -vmName myvm

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$vmName #VM to unprotect
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find VM
$vmid = (api get protectionSources/virtualMachines | Where-Object { $_.name -ieq $vmName }).id
"VM ID is $vmid"

### find protection job
if($vmid){
    $jobs = api get protectionJobs | Where-Object { $vmid -in $_.sourceIds }
    if($jobs){
        foreach($job in $jobs){
            "Removing $vmName from $($job.name)"
            $job.sourceIds = @($job.sourceIds | Where-Object { $_ -ne $vmid })
            $null = api put "protectionJobs/$($job.id)" $job
        }
    }else{
        Write-Warning "$vmName not protected"
    }
}else{
    Write-Warning "$vmName not found"
}
