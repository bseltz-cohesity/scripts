# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # folder to store export files
    [Parameter()][switch]$listRuns,
    [Parameter()][int64]$runId,
    [Parameter()][switch]$removeHold,
    [Parameter()][switch]$addHold,
    [Parameter()][switch]$latest,
    [Parameter()][datetime]$startDate,
    [Parameter()][datetime]$endDate
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$job = api get protectionJobs | Where-Object name -eq $jobName

if($job){
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=99999&excludeTasks=true" | Where-Object { $_.backupRun.snapshotsDeleted -eq $false }
    if($listRuns){
        $runs | Select-Object -Property @{label='RunId'; expression={$_.backupRun.jobRunId}}, @{label='RunDate'; expression={usecsToDate $_.backupRun.stats.startTimeUsecs}}
    }else{
        if($runId -or $latest -or ($startDate -and $endDate)){
            if($latest){
                $runs = $runs[0]
            }elseif($runId) {
                $runs = $runs | Where-Object {$_.backupRun.jobRunId -eq $runId}
            }elseif($startDate -and $endDate){
                "dates"
                $startDateUsecs = dateToUsecs $startDate
                $endDateUsecs = dateToUsecs $endDate
                $runs = $runs | Where-Object {$_.backupRun.stats.startTimeUsecs -ge $startDateUsecs -and $_.backupRun.stats.startTimeUsecs -le $endDateUsecs}
            }
            if($runs){
                foreach($run in $runs){
                    if($addHold -or $removeHold){
                        if($removeHold){
                            $holdValue = $false
                            "Removing legal hold from $($job.name): $(usecsToDate $run.backupRun.stats.startTimeUsecs)..."
                        }else{
                            $holdValue = $True
                            "Adding legal hold to $($job.name): $(usecsToDate $run.backupRun.stats.startTimeUsecs)..."
                        }
                        $runParams = @{
                            "jobRuns" = @(
                                @{
                                    "copyRunTargets"    = @();
                                    "runStartTimeUsecs" = $run.backupRun.stats.startTimeUsecs;
                                    "jobUid"            = $run.jobUid
                                }
                            )
                        }
                        foreach($copyRun in $run.copyRun){
                            $copyRunTarget = $copyRun.target
                            setApiProperty -object $copyRunTarget -name "holdForLegalPurpose" -value $holdValue
                            $runParams.jobRuns[0].copyRunTargets += $copyRunTarget
                        }
                        $null = api put protectionRuns $runParams
                    }else{
                        $legalHoldState = $false
                        foreach($copyRun in $run.copyRun){
                            if($True -eq $copyRun.holdForLegalPurpose){
                                $legalHoldState = $True
                            }
                        }
                        write-host "$($job.name): $(usecsToDate $run.backupRun.stats.startTimeUsecs): LegalHold = $legalHoldState"
                    }
                }
            }else{
                Write-Host "Run not found" -ForegroundColor Yellow
            }
        }
    }
}else{
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
}
