### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][int]$numRuns = 100
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
if($cohesity_api.api_version -lt '2025.01.10'){
    Write-Host "This script requires cohesity-api.ps1 version 2025.01.10 or later" -foregroundColor Yellow
    Write-Host "Please download it from https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api" -ForegroundColor Yellow
    exit
}

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

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure')

# $jobs = api get "protectionJobs"
$jobs = api get -v2 "data-protect/protection-groups?useCachedData=false&lastRunAnyStatus=Running&isDeleted=false&includeTenants=true&includeLastRunInfo=true"
$jobs = $jobs.protectionGroups

"jobName,startTime,targetType,status" | Out-File -FilePath ./runningJobs.csv

foreach($job in $jobs | Sort-Object -Property name){
    $v1JobId = ($job.id -split ':')[2]
    $runs = Get-Runs -jobId $v1JobId -includeRunning
    foreach ($run in $runs){
        $jobName = $run.jobName
        $runStartTime = $run.backupRun.stats.startTimeUsecs
        $startTime = usecsToDate $runStartTime
        foreach ($copyRun in $run.copyRun){
            if ($copyRun.status -notin $finishedStates){
                $overallstatus = $null
                $targetType = $copyRun.target.type.substring(1)
                $status = $copyRun.status.substring(1)
                "{0,-20} {1,-22} {2,-10} {3}" -f ($jobName, $startTime, $targetType, $status)
                "$jobName,$startTime,$targetType,$status" | Out-File -FilePath ./runningJobs.csv -Append
            }
        }
    }
}

$overallstatus
$overallstatus | Out-File -FilePath ./runningJobs.csv -Append
"`nOutput written to runningJobs.csv`n"
