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
$dateString = get-date -UFormat '%Y-%m-%d'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "dataPerObject-$($cluster.name)-$dateString.csv")
"Job Name,Object Name,Logical Size,Read Last 24 Hours ($unit),Read Last $daysBack Days ($unit),Written Last 24 Hours ($unit),Written Last $daysBack Days ($unit),Days Gathered" | Out-File -FilePath $outputfile

$jobs = api get protectionJobs | Where-Object {$_.isActive -ne $False -and $_.isDeleted -ne $True}
$today = Get-Date

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

        # logical size
        $logicalSize = $stats[$sourceName][0].logicalSize

        # last 24 hours
        $last24Hours = dateToUsecs ((get-date).AddDays(-1))
        $last24HourStats = $stats[$sourceName] | Where-Object {$_.startTimeUsecs -ge $last24Hours}
        $last24HoursDataRead = 0
        $last24HourStats.dataRead | foreach-object{ $last24HoursDataRead += $_ }
        $last24HoursDataWritten = 0
        $last24HourStats.dataWritten | ForEach-Object{ $last24HoursDataWritten += $_}

        # last X days
        $lastXDays = dateToUsecs ((get-date).AddDays(-$daysBack))
        $lastXDaysStats = $stats[$sourceName] | Where-Object {$_.startTimeUsecs -ge $lastXDays}
        $lastXDaysDataRead = 0
        $lastXDaysStats.dataRead | foreach-object{ $lastXDaysDataRead += $_ }
        $lastXDaysDataWritten = 0
        $lastXDaysStats.dataWritten | ForEach-Object{ $lastXDaysDataWritten += $_}

        # number of days gathered
        $oldestStat = usecsToDate $stats[$sourceName][-1]['startTimeUsecs']
        $numDays = ($today - $oldestStat).Days + 1

        "{0},{1},""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",{7}" -f $job.name, $sourceName, $(toUnits $logicalSize), $(toUnits $last24HoursDataRead), $(toUnits $lastXDaysDataRead), $(toUnits $last24HoursDataWritten), $(toUnits $lastXDaysDataWritten), $numDays | Out-File -FilePath $outputfile -Append
    }
}

"`nOutput saved to $outputfile`n"
