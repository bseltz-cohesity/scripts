# usage: ./backupInventory.ps1 -vip mycluster `
#                              -username myuser `
#                              -domain mydomain.net `
#                              -jobname myjob1, myjob2

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][Int64]$numRuns = 1000,
    [Parameter()][array]$jobname = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# filter on jobname
$jobs = api get protectionJobs
if($jobname){
    $jobs = $jobs | Where-Object { $_.name -in $jobname }
    $notfoundJobs = $jobname | Where-Object {$_ -notin $jobs.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$cluster = api get cluster
$daysBackUsecs = ($cluster.createdTimeMsecs * 1000)
$today = dateToUsecs (Get-Date)
$outFile = Join-Path -Path $PSScriptRoot -ChildPath "$($cluster.name)-backupInventory.txt"
"Backup inventory for $($cluster.name) ($(usecsToDate $today))" | Tee-Object -FilePath $outFile

"Searching for backups in retention..."

foreach ($job in $jobs | Sort-Object -Property name) {
    "`n$($job.name)" | Tee-Object -FilePath $outFile -Append

    $endUsecs = $today
    while($True){
        if($endUsecs -le $daysBackUsecs){
            break
        }
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true&excludeNonRestoreableRuns=true" | Where-Object {$_.backupRun.stats.endTimeUsecs -lt $endUsecs}
        if($runs){
            $endUsecs = $runs[-1].backupRun.stats.startTimeUsecs
        }else{
            break
        }
        foreach ($run in $runs){
            $showThisRun = $false
            $thisRunCopies = @()
            $startdate = usecstodate $run.copyRun[0].runStartTimeUsecs
            foreach($copyRun in $run.copyRun){
                $expiry = $copyRun.expiryTimeUsecs
                if(($expiry -gt $today) -or ($copyRun.holdForLegalPurpose -eq $True) -or ($null -ne $copyRun.legalHoldings)){
                    $showThisRun = $True
                    $thisRunCopies += $copyRun
                }
            }
            if($showThisRun){
                "`n    $startdate ($($run.backupRun.runType.subString(1).replace('Regular','Incremental')))" | Tee-Object -FilePath $outFile -Append
                foreach($copyRun in $thisRunCopies){
                    $onHold = ''
                    if($copyRun.holdForLegalPurpose -eq $True){
                        $onHold = '(On Legal Hold)'
                    }
                    if($null -ne $copyRun.legalHoldings){
                        $onHold = '(On Legal Hold)'
                    }
                    $expiryDate = (usecsToDate $copyRun.expiryTimeUsecs).ToString('yyyy-MM-dd')
                    $targetType = $copyRun.target.type.subString(1)
                    $target = 'Local'
                    if($targetType -eq 'Remote'){
                        $target = "$($copyRun.target.replicationTarget.clusterName) (Replica)"
                    }elseif ($targetType -eq 'Archival') {
                        $target = "$($copyRun.target.archivalTarget.vaultName) (Archive)"
                    }
                    "        {0} ({1}) - {2} {3}" -f $expiryDate, $copyRun.status.subString(1), $target, $onHold | Tee-Object -FilePath $outFile -Append
                }
            }
        }
    }
}
