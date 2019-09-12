### usage: ./restoreVMs.ps1 -vip mycluster -username myusername -domain mydomain.net -vmlist ./vmlist.txt

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][string]$vmlist = './vmlist.txt', # list of VMs to recover
    [Parameter()][string]$prefix = '',
    [Parameter()][switch]$poweron, # leave powered off by default
    [Parameter()][switch]$wait # wait for restore tasks to complete
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

if (!(Test-Path -Path $vmlist)) {
    Write-Host "vmlist file $vmlist not found" -ForegroundColor Yellow
    exit
}

$restores = @()
$restoreParams = @{}

# get list of VM backups

foreach($vm in get-content -Path $vmlist){
    # this VM
    $protectedVMs = api get "/searchvms?entityTypes=kVMware&vmName=$vm"
    $protectedVM = $protectedVMs.vms | Where-Object { $_.vmDocument.objectName -eq $vm }
    if($protectedVM){
        $protectedVM = $protectedVM[0]
        write-host "restoring $vm"
        if($protectedVM.registeredSource.id -notin $restores){
            # create restore parameters for this vCenter
            $restores += $protectedVM.registeredSource.id
            $recoverDate=(get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
            $restoreParams[$protectedVM.registeredSource.id] = @{
                "name"                         = "Recover-$($protectedVM.registeredSource.id)-$recoverDate";
                "objects"                      = @();
                "powerStateConfig"             = @{
                    "powerOn" = $false
                };
                "restoredObjectsNetworkConfig" = @{
                    "disableNetwork" = $false
                };
                "continueRestoreOnError"       = $false;
                "vaultRestoreParams"           = @{
                    "glacier" = @{
                        "retrievalType" = "kStandard"
                    }
                }
            }
            if($poweron){
                $restoreParams[$protectedVM.registeredSource.id].powerStateConfig.powerOn = $True
            }
            
            if($prefix -ne ''){
                $restoreParams[$protectedVM.registeredSource.id]['renameRestoredObjectParam'] = @{'prefix' = "$prefix"}
            }
        }
        # add this VM to list of VMs to restore
        $restoreObject = @{
            "jobId" = $protectedVM.vmDocument.objectId.jobId;
            "jobUid" = $protectedVM.vmDocument.objectId.jobUid;
            "entity" = $protectedVM.vmDocument.objectId.entity;
            "jobInstanceId" = $protectedVM.vmDocument.versions[0].instanceId.jobInstanceId;
            "startTimeUsecs" = $protectedVM.vmDocument.versions[0].instanceId.jobStartTimeUsecs
        }
        $restoreParams[$protectedVM.registeredSource.id].objects += $restoreObject
    }else{
        # no backups for this VM
        write-host "skipping $vm (not protected)"
    }
}

# perform the restores
$restoreTasks = @()
foreach ($parentId in $restoreParams.Keys) {
    $restore = api post /restore $restoreParams[$parentId]
    $taskid = $restore.restoreTask.performRestoreTaskState.base.taskId
    $restoreTasks += $taskid
}

# wait for restores to complete
if($wait){
    "Waiting for restores to complete..."
    $finishedStates = @('kCanceled', 'kSuccess', 'kFailure')
    $pass = 0
    foreach($taskid in $restoreTasks){
        do {
            if ($pass -gt 0){
                sleep 10
                $pass = 1
            }
            $restoreTask = api get /restoretasks/$taskid
            $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
        } until ($restoreTaskStatus -in $finishedStates)
        write-host "Restore task $($restoreTask.restoreTask.performRestoreTaskState.base.name) finished with status: $($restoreTask.restoreTask.performRestoreTaskState.base.publicStatus)"       
    }
}