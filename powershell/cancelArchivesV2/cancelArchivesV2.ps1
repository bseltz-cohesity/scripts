### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][switch]$cancelQueued,
   [Parameter()][switch]$cancelAll,
   [Parameter()][int]$numRuns = 9999
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning')

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "ArchiveQueue-$($cluster.name)-$dateString.csv"
"JobName,RunDate,$unit Transferred" | Out-File -FilePath $outfileName

$nowUsecs = dateToUsecs (get-date)

$runningTasks = 0

foreach($job in (api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true").protectionGroups | Sort-Object -Property name){
    $jobId = $job.id
    $jobName = $job.name
    "Getting tasks for $jobName"
    $runs = api get -v2 "data-protect/protection-groups/$jobId/runs?numRuns=$numRuns&includeTenants=true&includeObjectDetails=false"
    foreach($run in $runs.runs){
        $runId = $run.id
        $startTimeUsecs = $run.localBackupInfo.startTimeUsecs
        foreach($archivalInfo in $run.archivalInfo.archivalTargetResults){
            $taskId = $archivalInfo.archivalTaskId
            $status = $archivalInfo.status
            if($status -notin $finishedStates){
                $cancelling = ''
                if($cancelQueued -and $status -eq 'Accepted'){
                    $cancelling = '(Cancelling)'
                }
                if($cancelAll){
                    $cancelling = '(Cancelling)'
                }
                "  $status $(usecsToDate $startTimeUsecs) $cancelling"
                if($cancelling -ne ''){
                    $cancelParams = @{
                        "archivalTaskId" = @(
                              $taskId
                        )
                    }
                    $null = api post -v2 "data-protect/protection-groups/$jobId/runs/$runId/cancel" $cancelParams
                }
            }
        }
    }
}
