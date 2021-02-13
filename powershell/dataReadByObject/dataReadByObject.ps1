# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][Int64]$numRuns = 100,
    [Parameter()][Int64]$daysBack = 31,
    [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'GiB'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}

function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

# output file
$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d_%H-%M-%S'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "dataReadByObject-$($cluster.name)-$dateString.csv")
"Job Name,Object Name,Last 24 Hours ($unit),Last 7 Days ($unit),Daily Average ($unit),Monthly Estimate ($unit)" | Out-File -FilePath $outputfile

$jobs = api get protectionJobs | Where-Object {$_.isActive -ne $False -and $_.isDeleted -ne $True}

$daysBackUsecs = dateToUsecs (get-date -Hour 0 -Minute 00).AddDays(-$daysBack)

"`nGathering Job Statistics...`n"

foreach ($job in $jobs | Sort-Object -Property name) {
    $job.name
    $stats = @{}

    $endUsecs = dateToUsecs (Get-Date -Hour 0 -Minute 00)
    while($True){
        # paging: get numRuns at a time
        if($endUsecs -le $daysBackUsecs){
            break
        }
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeNonRestoreableRuns=true" | Where-Object {$_.backupRun.stats.endTimeUsecs -lt $endUsecs}
        if($runs){
            $endUsecs = $runs[-1].backupRun.stats.startTimeUsecs
        }else{
            break
        }

        # runs with undeleted snapshots
        foreach ($run in $runs | Where-Object{$_.backupRun.snapshotsDeleted -eq $false}){
            if($run.backupRun.stats.startTimeUsecs -le $daysBackUsecs){
                break
            }
            foreach($source in $run.backupRun.sourceBackupStatus){
                $sourceName = $source.source.name
                if($sourceName -notin $stats.Keys){
                    $stats[$sourceName] = @()
                }
                $stats[$sourceName] += @{'startTimeUsecs' = $run.backupRun.stats.startTimeUsecs;
                                        'dataRead' = $source.stats.totalBytesReadFromSource;
                                        'dataWritten' = $source.stats.totalPhysicalBackupSizeBytes;
                                        'logicalSize' = $source.stats.totalLogicalBackupSizeBytes}
            }
        }
    }
    foreach($sourceName in ($stats.Keys | sort)){
        "  $sourceName"

        # last 24 hours
        $last24Hours = dateToUsecs ((get-date).AddDays(-1))
        $last24HourStats = $stats[$sourceName] | Where-Object {$_.startTimeUsecs -ge $last24Hours}
        $last24HoursDataRead = 0
        $last24HourStats.dataRead | foreach-object{ $last24HoursDataRead += $_ }

        # last week
        $lastWeek = dateToUsecs ((get-date).AddDays(-7))
        $lastWeekStats = $stats[$sourceName] | Where-Object {$_.startTimeUsecs -ge $lastWeek}
        $lastWeekDataRead = 0
        $lastWeekStats.dataRead | foreach-object{ $lastWeekDataRead += $_ }

        # average read per day
        $averageDataRead = $lastWeekDataRead / 7

        # estimated 31 day total
        $monthlyRead = $averageDataRead * 31

        "{0},{1},""{2}"",""{3}"",""{4}"",""{5}""" -f $job.name, $sourceName, $(toUnits $last24HoursDataRead), $(toUnits $lastWeekDataRead), $(toUnits $averageDataRead), $(toUnits $monthlyRead) | Out-File -FilePath $outputfile -Append
    }
}

"`nOutput saved to $outputfile`n"
