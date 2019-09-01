### usage: ./backupVMsNow.ps1 -vip mycluster -username myusername -domain mydomain.net -vmlist ./vmlist.txt

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][string]$vmlist = './vmlist.txt' # list of VMs to backup
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

if (!(Test-Path -Path $vmlist)) {
    Write-Host "vmlist file $vmlist not found" -ForegroundColor Yellow
    exit
}

$jobs = api get protectionJobs
$jobsToRun = @()
$vmIds = @{}

$protectedVMs = api get protectionSources/virtualMachines?protected=true

foreach($vm in get-content -Path $vmlist){
    $protectedVM = $protectedVMs | Where-Object { $_.name -eq $vm }
    if($protectedVM){
        $job = $jobs | where-object { $protectedVM.id -in $_.sourceIds }
        if($job){
            write-host "Backing up $vm ($($job.name))"
            if($job.id -notin $jobsToRun){
                $jobsToRun += $job.id
                $vmIds[$job.id]=@($protectedVM.id)
            }else{
                $vmIds[$job.id] += $protectedVM.id
            }
        }
    }else{
        write-host "$vm is not protected"
    }
}

foreach ($jobId in $vmIds.Keys) {
    $runParams = @{
        "copyRunTargets" = @();
        "sourceIds"      = $vmIds[$jobId];
        "runType"        = "kRegular"
    }
    $null = api post protectionJobs/run/$jobId $runParams
}
