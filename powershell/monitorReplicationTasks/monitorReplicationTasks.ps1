### usage: ./monitorReplicationTasks.ps1 -vip mycluster -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][Int64]$daysBack = 7,
    [Parameter()][Int64]$numRuns = 9999,
    [Parameter()][switch]$lastOnly,
    [Parameter()][switch]$runningOnly
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$outFile = "$($cluster.name)-replicationStatus.csv"

### find protectionRuns with active replication tasks
$daysBackUsecs = dateToUsecs ((Get-Date).AddDays(-$daysBack))
$finishedStates = @('Canceled', 'Succeeded', 'Failed')
$foundOne = $false
if($lastOnly){
    $numRuns = 1
}

"`nLooking for Replication Tasks...`n"
"Job Name,Run Date,Target,Status,Replication Start,Replication End" | Out-File -FilePath $outFile
foreach ($job in (api get -v2 data-protect/protection-groups?isActive=true).protectionGroups | Sort-Object -Property name){
    $jobName = $job.name
    "  $jobName"
    foreach($run in (api get -v2 "data-protect/protection-groups/$($job.id)/runs?startTimeUsecs=$daysBackUsecs&numRuns=$numRuns&includeTenants=true&includeObjectDetails=false").runs){
        $runDate = usecsToDate $run.localBackupInfo.startTimeUsecs
        if($run.PSObject.Properties['replicationInfo']){
            foreach($replication in $run.replicationInfo.replicationTargetResults){
                $target = $replication.clusterName
                $status = $replication.status
                $replicationStart = '-'
                $replicationEnd = '-'
                if($replication.PSObject.Properties['startTimeUsecs']){
                    $replicationStart = usecsToDate $replication.startTimeUsecs
                }
                if($replication.PSObject.Properties['endTimeUsecs']){
                    $replicationEnd = usecsToDate $replication.endTimeUsecs
                }
                if(!$runningOnly -or $status -notin $finishedStates){
                    $foundOne = $True
                    Write-Host "      $runDate -> $target ($status)"
                    "$jobName,$runDate,$target,$status,$replicationStart,$replicationEnd" | Out-File -FilePath $outFile -Append
                }  
            }
        }
    }
}

if($false -eq $foundOne){
    write-host "`nNo replication tasks found`n"
}else{
    Write-Host "`nOutput saved to $outFile`n"
}
