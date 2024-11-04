# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$job = api get protectionJobs | Where-Object name -eq $jobName

if($job){
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=99999&excludeTasks=true&excludeNonRestorableRuns=true" | Where-Object { $_.backupRun.snapshotsDeleted -eq $false }
    if($listRuns){
        $runs | Select-Object -Property @{label='RunId'; expression={$_.backupRun.jobRunId}}, @{label='RunDate'; expression={usecsToDate $_.backupRun.stats.startTimeUsecs}}
    }else{
        if($runId -or $latest -or ($startDate -and $endDate)){
            if($latest){
                $runs = $runs[0]
            }elseif($runId) {
                $runs = $runs | Where-Object {$_.backupRun.jobRunId -eq $runId}
            }elseif($startDate -and $endDate){
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
                        $thisRun = api get "/backupjobruns?id=$($run.jobId)&exactMatchStartTimeUsecs=$($run.backupRun.stats.startTimeUsecs)"
                        $jobUid = @{
                            "clusterId" = $thisRun.backupJobRuns.protectionRuns[0].backupRun.base.jobUid.clusterId;
                            "clusterIncarnationId" = $thisRun.backupJobRuns.protectionRuns[0].backupRun.base.jobUid.clusterIncarnationId;
                            "id" = $thisRun.backupJobRuns.protectionRuns[0].backupRun.base.jobUid.objectId;
                        }
                        $runParams = @{
                            "jobRuns" = @(
                                @{
                                    "copyRunTargets"    = @();
                                    "runStartTimeUsecs" = $run.backupRun.stats.startTimeUsecs;
                                    "jobUid"            = $jobUid
                                }
                            )
                        }
                        foreach($copyRun in $run.copyRun | Where-Object {$_.target.type -in @('kLocal', 'kArchival')}){
                            $copyRunTarget = $copyRun.target
                            setApiProperty -object $copyRunTarget -name "holdForLegalPurpose" -value $holdValue
                            $runParams.jobRuns[0].copyRunTargets += $copyRunTarget
                        }
                        
                        $null = api put protectionRuns $runParams
                    }else{
                        $legalHoldState = $false
                        foreach($copyRun in $run.copyRun | Where-Object {$_.target.type -in @('kLocal', 'kArchival')}){
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