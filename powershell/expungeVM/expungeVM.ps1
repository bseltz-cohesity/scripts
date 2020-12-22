# usage: 
# ./expungeVM.ps1 -vip mycluster `
#                 -username admin `
#                 -domain local `
#                 -vmName myvm `
#                 -jobName myjob `
#                 -delete

# note: -delete switch actually performs the delete, otherwise just perform a test run
# processing is logged at <scriptpath>/expungeVMLog.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][array]$vmName,  # optional names of vms to expunge (comma separated)
    [Parameter()][string]$vmList = '',  # optional textfile of vms to expunge (one per line)
    [Parameter()][string]$jobName,
    [Parameter()][string]$tenantId = $null,
    [Parameter()][int]$olderThan = 0,
    [Parameter()][switch]$delete # delete or just a test run
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -tenantId $tenantId.ToUpper()

# gather list of vms to expunge

$vms = @()
foreach($v in $vmName){
    $vms += $v
}
if ('' -ne $vmList){
    if(Test-Path -Path $vmList -PathType Leaf){
        $vmfile = Get-Content $vmList
        foreach($v in $vmfile){
            $vms += [string]$v
        }
    }else{
        Write-Warning "VM list $vmList not found!"
        exit
    }
}

# logging 

$runDate = get-date -UFormat %Y-%m-%d_%H-%M-%S
$logfile = Join-Path -Path $PSScriptRoot -ChildPath "expungeVMLog-$runDate.txt"

function log($text){
    "$text" | Tee-Object -FilePath $logfile -Append
}

log "- Started at $(get-date) -------`n"

# display run mode

if ($delete) {
    log "----------------------------------"
    log "  *PERMANENT DELETE MODE*         "
    log "  - selection will be deleted!!!"
    log "  - logging to $logfile"
    log "  - press CTRL-C to exit"
    log "----------------------------------`n"
}
else {
    log "--------------------------"
    log "  *TEST RUN MODE*"
    log "  - not deleting"
    log "  - logging to $logfile"
    log "--------------------------`n"
}

$remoteClusters = @()

$olderThanUsecs = dateToUsecs (get-date).AddDays(-$olderThan)

foreach($vName in $vms){
    $vName = [string]$vName
    # search for VM
    log "`nSearching for $vName...`n"
    $search = api get "/searchvms?entityTypes=kVMware&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kAcropolis&entityTypes=kKVM&entityTypes=kAWS&vmName=$([uri]::EscapeUriString($vName))"
    $foundvms = $search.vms | Where-Object { $_.vmDocument.objectName -eq $vName }
    foreach($vm in $foundvms){
        $doc = $vm.vmDocument
        if((! $jobName) -or $jobName -eq $doc.jobName){
            foreach($version in $doc.versions){
                if($version.instanceId.jobStartTimeUsecs -lt $olderThanUsecs){
                    $canDelete = $false
                    $runParameters = @{
                        "jobRuns" = @(
                            @{
                                "copyRunTargets"    = @();
                                "runStartTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                                "jobUid"            = @{
                                    "clusterId"            = $doc.objectId.jobUid.clusterId;
                                    "clusterIncarnationId" = $doc.objectId.jobUid.clusterIncarnationId;
                                    "id"                   = $doc.objectId.jobUid.objectId
                                };
                                "sourceIds"         = @(
                                    $doc.objectId.entity.id
                                )
                            }
                        )
                    }
                    foreach($replica in $version.replicaInfo.replicaVec){
                        if($replica.target.type -eq 1){
                            $canDelete = $True
                            $runParameters.jobRuns[0].copyRunTargets += @{
                                'daysToKeep' = 0;
                                'type'       = 'kLocal'
                            }
                        }
                        if($replica.target.type -eq 2){
                            if($replica.target.replicationTarget.clusterName -notin $remoteClusters){
                                $remoteClusters += $replica.target.replicationTarget.clusterName 
                            }
                        }
                        if($replica.target.type -eq 3 -and $replica.target.archivalTarget.type -eq 0){
                            $canDelete = $True
                            $runParameters.jobRuns[0].copyRunTargets += @{
                                'daysToKeep' = 0;
                                'type' = 'kArchival';
                                'archivalTarget' = @{
                                    'vaultName' = $replica.target.archivalTarget.name;
                                    'vaultId'= $replica.target.archivalTarget.vaultId;
                                    'vaultType' = 'kCloud'
                                }
                            }
                        }
                    }
                    if($True -eq $canDelete){
                        if($delete){
                            log ("deleting {0} from {1} ({2})" -f $vName, $($doc.jobName), $(usecsToDate $version.instanceId.jobStartTimeUsecs))
                            $null = api put protectionRuns $runParameters
                        }else{
                            log ("found {0} in {1} ({2})" -f $vName, $($doc.jobName), $(usecsToDate $version.instanceId.jobStartTimeUsecs))
                        }
                    }
                }
            }
        }
    }
}

if($remoteClusters.Count -gt 0){
    log ("`nReplicas detected on other clusters: {0}" -f $remoteClusters -join ', ')
    log ("Please run this script against those clusters to delete those replicas")
}

log "`n- Ended at $(get-date) -------`n`n"
