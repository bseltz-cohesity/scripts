# usage: ./expungeVM.ps1 -vip mycluster -username admin [ -domain local ] -vmName myvm [ -delete ]

# note: -delete switch actually performs the delete, otherwise just perform a test run
# processing is logged at <scriptpath>/expungeVMLog.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$vmName, # VM to expunge
    [Parameter()][switch]$delete # delete or just a test run
)

# logging 

$scriptdir = Split-Path -parent $PSCommandPath
$runDate = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$logfile = Join-Path -Path $scriptdir -ChildPath "expungeVMLog-$runDate.txt"
$global:logItem=''

function log($text){
    "$text"
    $Global:logItem += "$text`n"
}

log "- Started at $(get-date) -------`n"

# display run mode

if ($delete) {
    log "----------------------------------"
    log "  *PERMANENT DELETE MODE*         "
    log "  - selection will be deleted!!!"
    log "  - logging to $logfile"
    log "  - press CTRL-C to exit"
    log "----------------------------------"
}
else {
    log "--------------------------"
    log "    *TEST RUN MODE*  "
    log "    - not deleting"
    log "    - not logging"
    log "--------------------------"
}

$archiveType = @{'0' = "kCloud"; '1' = "kTape" }

$clusters = @()
$instanceList = @()
$instanceNum = 1
$backupList = @()
$backupNum = 0
$clusterNames = @{}
$foreignDetections = @()

# source the cohesity-api helper code
. ./cohesityCluster.ps1

# authenticate to local and remote clusters
log "`nConnecting to local cluster $vip..."
$cluster = connectCohesityCluster -server $vip -username $username -domain $domain -quiet
$clusterInfo = $cluster.get('cluster')
$localClusterId = $clusterInfo.id
$localClusterIncarnationId = $clusterInfo.incarnationId
$clusters += $cluster
$clusterNames[[string]$localClusterId] = $clusterInfo.name

$remotes = $cluster.get('remoteClusters')
foreach ($remote in $remotes){
    $remoteIP = $remote.remoteIps[0]
    log "Connecting to remote cluster $($remote.name)..."
    $cluster = connectCohesityCluster -server $remoteIP -username $username -domain $domain -quiet
    $clusters += $cluster
    $clusterInfo = $cluster.get('cluster')
    $clusterId = $clusterInfo.id
    $clusterNames[[string]$clusterId] = $clusterInfo.name
}

# search for VM
log "`nSearching for $vmName...`n"

foreach($cluster in $clusters){
    $clusterInfo = $cluster.get('cluster')
    $clusterName = $clusterInfo.name
    $clusterId = $clusterInfo.id

    write-host "  on $clusterName..."
    $jobs = $cluster.get('protectionJobs')
    $search = $cluster.get("/searchvms?entityTypes=kVMware&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kAcropolis&entityTypes=kKVM&entityTypes=kAWS&vmName=$vmName")
    #$vm = $search.vms | Where-Object { $_.vmDocument.objectName -eq $vmName -and $_.vmDocument.objectId.jobUid.clusterId -eq $clusterId }
    $vm = $search.vms | Where-Object { $_.vmDocument.objectName -eq $vmName }
    if($vm){
        $vm = $vm[0]
        # get versions
        $clusterId = $vm.vmDocument.objectId.jobUid.clusterId
        $jobId = $vm.vmDocument.objectId.jobId
        $job = $jobs | Where-Object { $_.id -eq $jobId }
        $jobName = $job.name
        $policyId = $job.policyId
        $origJobId = $vm.vmDocument.objectId.jobUid.objectId
        $policyClusterId = $policyId.split(':')[0]
        $objectName = $vm.vmDocument.objectId.entity.displayName
        if($policyClusterId -eq $localClusterId){
            $runs = $cluster.get("protectionRuns?jobId=$jobId&numRuns=999999&excludeNonRestoreableRuns=true&excludeTasks=true")
            foreach ($version in $vm.vmDocument.versions) {
                $exactRun = $runs | Where-Object {$_.backupRun.jobRunId -eq $version.instanceId.jobInstanceId }
                # get locations
                $locations = @()
                foreach($replica in $version.replicaInfo.replicaVec){
                    if($replica.expiryTimeUsecs -ne 0 -and $replica.expiryTimeUsecs -gt (dateToUsecs (get-date))){
                        if ($replica.target.type -ne 2) {
                            if($replica.target.type -eq 3){
                                $target = $replica.target
                            }else{
                                $target = @{'type' = 1}
                            }
                            $location = @{
                                'cluster' = $cluster;
                                'clusterName' = $clusterName;
                                'target' = $target;
                                'sourceId' = $vm.vmDocument.objectId.entity.id;
                            }
                            $locations += $location
                        }
                    }
                }

                if($locations.count -gt 0){

                    $instance = $instanceList | Where-Object { $_.objectName -eq $objectName -and $_.jobName -eq $jobName}
                    if(! $instance){
                        $instance = @{
                            'objectName' = $objectName;
                            'jobName' = $jobName;
                            'instanceNum' = $instanceNum
                        }
                        $instanceNum++
                        $instanceList += $instance
                    }
                        
                    $backup = $backupList | Where-Object {$_.objectName -eq $objectName -and $_.jobName -eq $jobName -and $_.startTimeUsecs -eq $exactRun.copyRun[0].runStartTimeUsecs}
                    if($backup){
                        $backup.locations += $locations
                        if($instance.instanceNum -in $backup.instanceNum -eq $false){
                            $backup.instanceNum = $backup.instanceNum + $instance.instanceNum
                        }
                    }else{
                        $backup = @{
                            'objectName' = $objectName;
                            'jobName' = $jobName;
                            'startTimeUsecs' = $exactRun.copyRun[0].runStartTimeUsecs;
                            'versionNum' = $backupNum++;
                            'locations' = $locations;
                            'instanceNum' = @($instance.instanceNum)
                            'jobUid' = @{
                                'id' = $origJobId;
                                'clusterId' = $localClusterId;
                                'clusterIncarnationId' = $localClusterIncarnationId
                            }
                        }
                        # $exactRun.jobUid
                        $backupList += $backup 
                    }
                }
            }
        }else{
            if([string]$policyClusterId -in $clusterNames.Keys){
                $foreignCluster = $clusterNames[[string]$policyClusterId]
            }else{
                $foreignCluster = $policyClusterId
            }
            if ($foreignCluster -in $foreignDetections -eq $false){
                $foreignDetections += $foreignCluster
            }
        }
    }
}

# display discovered runs
if($backupList.count -gt 0){
    log "`nFound the VM in the following protection runs:`n"
    foreach ($backup in $backupList){
        log ("    {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
    }
}else{
    log "`n* No Results Found *"
    log "`n- Ended at $(get-date) -------`n`n"
    if($delete){
        $global:logItem | Out-File $logfile -Append
    }
    exit
}



# process deletes
if($delete){
    log "`nDeleting backups...`n"
    foreach($backup in $backupList){
        log ("  Deleting {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
        foreach($location in $backup.locations){
            $updateProtectionJobRunsParam = @{
                'jobRuns' = @(
                    @{
                        'copyRunTargets'    = @();
                        'runStartTimeUsecs' = $backup.startTimeUsecs;
                        'jobUid'            = $backup.jobUid;
                        'sourceIds'         = @(
                            $location.sourceId
                        )
                    }
                )
            }
            if($location.target.type -eq 1){
                log ("                        from {0}" -f $location.clusterName)
                $updateProtectionJobRunsParam.jobRuns[0].copyRunTargets += @{
                        'daysToKeep' = 0;
                        'type'       = 'kLocal'
                    }
            }
            if($location.target.type -eq 3){
                log ("                        from {0}" -f $location.target.archivalTarget.name)
                $updateProtectionJobRunsParam.jobRuns[0].copyRunTargets += @{
                    'daysToKeep' = 0;
                    'type' = 'kArchival';
                    'archivalTarget' = @{
                        'vaultName' = $location.target.archivalTarget.name;
                        'vaultId'= $location.target.archivalTarget.vaultId;
                        'vaultType' = $archiveType[[string]$location.target.archivalTarget.type]
                    }
                }

            }
            # $updateProtectionJobRunsParam | ConvertTo-Json -Depth 99
            $null = $location.cluster.put("protectionRuns", $updateProtectionJobRunsParam)
            $location['deleted'] = $True
        }
    }
}

# display processed results
log "`nEnd state of protection runs:`n"
foreach ($backup in $backupList){

    $deleted=$True
    foreach($location in $backup.locations){
        if($location.contains('deleted') -eq $false){
            $deleted = $false 
        }
    }
    if($deleted -eq $false){
        log ("  (Retained) {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
    }else{
        log ("  (Deleted)  {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
    }
}

if($foreignDetections.count -gt 0){
    log ("`n* Notice! ***************************************************`n*")
    log ("* Additional Instances of {0} detected" -f $vmName)
    log "* in backups originating from the following clusters"
    log "* Please re-run the script on these clusters:`n*"
    foreach ($clusterName in $foreignDetections){
        log "* $clusterName"
    }
    log "*`n*************************************************************"
}

log "`n- Ended at $(get-date) -------`n`n"
if($delete){
    $global:logItem | Out-File $logfile -Append
}
