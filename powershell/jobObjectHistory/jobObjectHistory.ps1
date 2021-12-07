# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$numRuns = 100
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# output file
$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "jobObjectHistory-$($cluster.name)-$dateString.txt")
"===========`n$($cluster.name)`n===========" | Tee-Object -FilePath $outputfile 
$jobs = api get protectionJobs | Where-Object {$_.isActive -ne $False -and $_.isDeleted -ne $True}

foreach($job in $jobs | Sort-Object -Property name){
    "`n$($job.name)`n"
    $jobNameReported = $False
    $previousSourceList = @()
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns" | Where-Object {$_.backupRun.snapshotsDeleted -ne $true}
    foreach($run in $runs | Sort-Object -Property {$_.backupRun.stats.startTimeUsecs}){
        "    $(usecsToDate $run.backupRun.stats.startTimeUsecs)"
        $sourceList = $run.backupRun.sourceBackupStatus.source.name
        if($previousSourceList -ne @()){
            $added = $sourceList | Where-Object {$_ -notin $previousSourceList} | sort
            $removed = $previousSourceList | Where-Object {$_ -notin $sourceList} | sort
            if($added.Count -gt 0 -or $removed.Count -gt 0){
                if($jobNameReported -eq $False){
                    "`n$($job.name)  (Last Modified by $($job.modifiedByUser) at $(usecsToDate $job.modificationTimeUsecs))`n" | Out-File -FilePath $outputfile -Append
                    $jobNameReported = $True
                }
                "    $(usecsToDate $run.backupRun.stats.startTimeUsecs)" | Out-File -FilePath $outputfile -Append
            }
            foreach($add in $added){
                "        ********     Added: $add" | Tee-Object -FilePath $outputfile -Append
            }
            foreach($remove in $removed){
                "        ********   Removed: $remove" | Tee-Object -FilePath $outputfile -Append
            }
        }
        $previousSourceList = $sourceList
    }
}
"`nOutput saved to $outputfile`n"
