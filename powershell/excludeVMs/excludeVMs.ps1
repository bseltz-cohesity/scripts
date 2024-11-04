### usage: ./excludeVMs.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'vm backup' -vmName mongodb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$vmName,  # name of VM to protect
    [Parameter()][string]$vmList = '',  # text file of vm names
    [Parameter()][string]$vmMatch,
    [Parameter()][switch]$prefixMatch,
    [Parameter()][array]$jobName,
    [Parameter()][switch]$removeExclusion
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

### get the protectionJob
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware"

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
if($vmsToExclude.Count -eq 0 -and ! $vmMatch){
    Write-Host "No VMs to add" -ForegroundColor Yellow
    exit
}

if($prefixMatch){
    $vmMatch = "^$vmMatch"
}
$vmsAdded = $false
$vmcache = @{}
$vCenterCache = @{}

foreach($job in $jobs.protectionGroups){
    if($job.name -in $jobName -or $jobName.Count -eq 0){
        if($vCenterCache["$($job.vmwareParams.sourceId)"]){
            $vms = $vCenterCache["$($job.vmwareParams.sourceId)"]
        }else{
            $vms = api get protectionSources/virtualMachines?vCenterId=$($job.vmwareParams.sourceId)
            $vCenterCache["$($job.vmwareParams.sourceId)"] = $vms
        }
        if($vmMatch){
            $matchVMs = $vms | Where-Object {$_.name -match $vmMatch}
            $vmsToExclude = @($vmsToExclude + $matchVMs.name | Sort-Object -Unique)
        }
        foreach($vmName in $vmsToExclude){
            ### get the VM
            $vm = $vms | Where-Object {$_.name -ieq $vmName}
            if(!$vm){
                Write-Host "VM $vmName not found!" -ForegroundColor Yellow
            }else{
                $vmcache[$vmName] = $vm
                $vmsAdded = $True
                if($removeExclusion){
                    Write-Host "Removing exclusion for $vmName from $($job.name)"
                    if($job.vmwareParams.PSObject.Properties['excludeObjectIds']){
                        $job.vmwareParams.excludeObjectIds = @($job.vmwareParams.excludeObjectIds | Where-Object {$_ -ne $vm.id})
                    }
                }else{
                    Write-Host "Excluding $vmName from $($job.name)"
                    if(!$job.vmwareParams.PSObject.Properties['excludeObjectIds']){
                        setApiProperty -object $job.vmwareParams -name 'excludeObjectIds' -value @($vm.id)
                    }else{
                        $job.vmwareParams.excludeObjectIds = @($job.vmwareParams.excludeObjectIds + $vm.id)
                    }
                }
            } 
        }
        ### update the job
        if($vmsAdded){
            $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
        }
    }
}


