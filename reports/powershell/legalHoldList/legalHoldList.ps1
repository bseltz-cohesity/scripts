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
    [Parameter()][array]$jobname = $null,
    [Parameter()][ValidateSet("kRegular","kFull","kLog","kSystem","kAll")][string]$backupType = 'kAll',
    [Parameter()][Int64]$numRuns = 1000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

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

$dateString = (Get-Date).ToString('yyyy-MM-dd')
$outfile = "legalHolds-$($cluster.name)-$dateString.csv"
"Job Name,RunDate" | Out-File -FilePath $outfile

# find protectionRuns that are older than daysToKeep
Write-Host "`nSearching for legal holds...`n"

foreach ($job in $jobs | Sort-Object -Property name) {
    Write-Host "$($job.name)"
    $jobId = $job.id

    $endUsecs = dateToUsecs (Get-Date)
    while($True){
        # paging: get numRuns at a time
        if($endUsecs -le $daysBackUsecs){
            break
        }
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true&excludeNonRestoreableRuns=true" | Where-Object {$_.backupRun.stats.endTimeUsecs -lt $endUsecs}
        if($runs){
            $endUsecs = $runs[-1].backupRun.stats.startTimeUsecs
        }else{
            break
        }
        # runs with undeleted snapshots
        foreach ($run in $runs | Where-Object{$_.backupRun.snapshotsDeleted -eq $false -and ($_.backupRun.runType -eq $backupType -or $backupType -eq 'kAll')}){
            if($run.backupRun.stats.startTimeUsecs -le $daysBackUsecs){
                break
            }
            $startdate = usecstodate $run.copyRun[0].runStartTimeUsecs
            $startdateusecs = $run.copyRun[0].runStartTimeUsecs
            if ($run.copyRun[0].holdForLegalPurpose -eq $True -or $run.copyRun[0].legalHoldings){
                write-host "    $startdate"
                "$($job.name),$startdate" | Out-File -FilePath $outfile -Append
            }
        }
    }
}

Write-Host "`nOutput saved to $outfile`n"
