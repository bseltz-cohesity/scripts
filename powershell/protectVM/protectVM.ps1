### usage: ./protectVM.ps1 -vip bseltzve01 -username admin -jobName 'vm backup' -vmName mongodb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][array]$vmName,  # name of VM to protect
    [Parameter()][string]$vmList = '',  # text file of vm names
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add VM to
    [Parameter()][array]$excludeDisk
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

# validate exclude disks
foreach($disk in $excludeDisk){
    if($disk -notmatch '([0-9]|[0-9][0-9]):([0-9]|[0-9][0-9])'){
        Write-Host "excludeDisk must be in the format busNumber:unitNumber - e.g. 0:1" -ForegroundColor Yellow
        exit
    }
}

# gather list of servers to add to job
$vmsToAdd = @()
foreach($v in $vmName){
    $vmsToAdd += $v
}
if ('' -ne $vmList){
    if(Test-Path -Path $vmList -PathType Leaf){
        $servers = Get-Content $vmList
        foreach($server in $servers){
            $vmsToAdd += [string]$server
        }
    }else{
        Write-Host "VM list $vmList not found!" -ForegroundColor Yellow
        exit
    }
}
if($vmsToAdd.Count -eq 0){
    Write-Host "No VMs to add" -ForegroundColor Yellow
    exit
}

$vmsAdded = $false

foreach($vmName in $vmsToAdd){
    ### get the VM
    $vm = api get protectionSources/virtualMachines?vCenterId=$($job.parentSourceId) | Where-Object {$_.name -ieq $vmName}
    if(!$vm){
        Write-Host "VM $vmName not found!" -ForegroundColor Yellow
    }else{
        $vmsAdded = $True
        if($vm.id -in $job.sourceIds){
            Write-Host "VM $($vm.name) already in job $($job.name)"
        }else{
            $job.sourceIds += $vm.id
            Write-Host "Adding $($vm.name) to $($job.name) job"
        }
        if(! $job.PSObject.Properties['sourceSpecialParameters']){
            setApiProperty -object $job -name 'sourceSpecialParameters' -value @()
        }
        $job.sourceSpecialParameters = @($job.sourceSpecialParameters | Where-Object {$_.sourceId -ne $vm.id})
        $excludedDisks = @()
        foreach($disk in $excludeDisk){
            $busNumber, $unitNumber = $disk.split(":")
            $vdisk = $vm.vmWareProtectionSource.virtualDisks | Where-Object {$_.busNumber -eq $busNumber -and $_.unitNumber -eq $unitNumber}
            if($vdisk){
                $excludedDisks += @{
                    "controllerType" = $vdisk.controllerType;
                    "busNumber" = $vdisk.busNumber;
                    "unitNumber" = $vdisk.unitNumber
                }
            }
        }
        if($excludedDisks.count -gt 0){
            $job.sourceSpecialParameters += @{
                "sourceId" = $vm.id; 
                "vmwareSpecialParameters" = @{
                    "excludedDisks" = $excludedDisks
                }
            }
        }
    }    
}

### update the job
if($vmsAdded){
    $null = api put protectionJobs/$($job.id) $job
}
