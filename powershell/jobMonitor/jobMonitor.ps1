# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][int]$numRuns = 10,
    [Parameter()][switch]$showObjects
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit
}

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

# jobs = [job for job in api('get', 'protectionJobs') if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False)]
$jobs = api get "protectionJobs"

# catch invalid job names
if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit
    }
}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning', 'kCanceling', '3', '4', '5', '6')
$statusMap = @('0', '1', '2', 'Canceled', 'Success', 'Failed', 'Warning')

foreach($job in $jobs | Sort-Object -Property name| Where-Object {$_.isDeleted -ne $true -and $_.isActive -ne $false}){

    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        "{0}" -f $job.name
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns"
        $runningCount = 0
        foreach($run in $runs){
            $status = $run.backupRun.status
            if($status -notin $finishedStates){
                $runningCount += 1
                $startTime = usecsToDate $run.backupRun.stats.startTimeUsecs
                try{
                    $progressTotal = 0
                    $sourceCount = $run.backupRun.sourceBackupStatus.Count
                    foreach($source in $run.backupRun.sourceBackupStatus | Sort-Object -Property {$_.source.name}){
                        $sourceName = $source.source.name
                        $progressPath = $source.progressMonitorTaskPath
                        $progressMonitor = api get "/progressMonitors?taskPathVec=$progressPath&includeFinishedTasks=true&excludeSubTasks=false"
                        $thisProgress = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
                        $progressTotal += $thisProgress
                        if($showobjects){
                            "    $($startTime):  $([math]::Round($thisProgress, 0))% completed`t$sourceName"
                        }                           
                    }
                    $percentComplete = [math]::Round($progressTotal / $sourceCount, 0)
                    if(! $showobjects){
                        "    $($startTime): $percentComplete% completed"
                    }
                }catch{
                    # pass
                }
            }
        }
    }
}

