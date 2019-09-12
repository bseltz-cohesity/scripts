### usage: ./backupVMsNow.ps1 -vip mycluster -username myusername -domain mydomain.net -vmlist ./vmlist.txt

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][string]$vmlist = './vmlist.txt', # list of VMs to backup
    [Parameter()][switch]$wait #wait for jobs to complete
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

# get list of protected VMs
$protectedVMs = api get protectionSources/virtualMachines?protected=true

foreach($vm in get-content -Path $vmlist){
    # this protected VM
    $protectedVM = $protectedVMs | Where-Object { $_.name -eq $vm }
    if($protectedVM){
        # find my job
        $job = $null
        $foundVMs = api get /searchvms?vmName=$vm
        if($foundVMs.vms.count -gt 0){
            $foundVM = $foundVMs.vms | Where-Object {$_.vmDocument.objectName -eq $vm}
            $jobName = $foundVM.vmDocument.jobName
            $job = $jobs | where-object { $jobName -eq $_.name }
        }
        if($job){
            write-host "Adding $vm ($($job.name))"
            # add vm to run now list for this job
            if($job.id -notin $jobsToRun){
                $jobsToRun += $job.id
                $vmIds[$job.id]=@($protectedVM.id)
            }else{
                $vmIds[$job.id] += $protectedVM.id
            }
        }else{
            write-host "No job found for $vm"
        }
    }else{
        # this VM is not in a job
        write-host "Skipping $vm (not protected)"
    }
}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure')
$currentRunIds = @{}

# wait for existing job run to finish
$reportWaiting = $True
foreach ($jobId in $jobsToRun) {
    $runs = api get "protectionRuns?jobId=$jobId&numRuns=10"
    $currentRunIds[$jobId] = $runs[0].backupRun.jobRunId
    while ($runs[0].backupRun.status -notin $finishedStates){
        if($reportWaiting){
            "waiting for existing job run to finish..."
            $reportWaiting = $false
        }
        sleep 5
        $runs = api get "protectionRuns?jobId=$($jobId)&numRuns=10"
    }
}

# run jobs
foreach ($jobId in $jobsToRun) {
    $runParams = @{
        "copyRunTargets" = @();
        "sourceIds"      = $vmIds[$jobId];
        "runType"        = "kRegular"
    }
    $null = api post protectionJobs/run/$jobId $runParams
}

if($wait){
    "waiting for completion..."
    # wait for new job run to appear
    foreach ($jobId in $jobsToRun) {
        $newRunId = $currentRunIds[$jobId]
        while($newRunId -eq $currentRunIds[$jobId]){
            sleep 2
            $runs = api get "protectionRuns?jobId=$($jobId)&numRuns=10"
            $newRunId = $runs[0].backupRun.jobRunId
        }
    }

    # wait for job run to finish
    foreach ($jobId in $jobsToRun) {
        $runs = api get "protectionRuns?jobId=$($jobId)&numRuns=10"
        while ($runs[0].backupRun.status -notin $finishedStates){
            sleep 5
            $runs = api get "protectionRuns?jobId=$($jobId)&numRuns=10"
        }
        Write-Host "Job $($runs[0].jobName) finished with status: $($runs[0].backupRun.status)"
    }
}
