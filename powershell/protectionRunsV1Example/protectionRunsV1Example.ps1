# process commandline arguments
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
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][int]$daysBack
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

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "baseV1-$($cluster.name)-$dateString.csv"

# headings
"Job Name, Run Date" | Out-File -FilePath $outfileName -Encoding utf8


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

$jobs = api get "protectionJobs"

# catch invalid job names
if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$daysBackUsecs = $cluster.createdTimeMsecs * 1000
if($daysBack){
    $daysBackUsecs = timeAgo $daysBack 'days'
}

foreach($job in $jobs | Sort-Object -Property name | Where-Object {$_.isDeleted -ne $true}){
    $endUsecs = dateToUsecs (Get-Date)
    $lastRunId = 0
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        "{0}" -f $job.name
        while($True){
            $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&startTimeUsecs=$daysBackUsecs&endTimeUsecs=$endUsecs&excludeTasks=true"
            if($lastRunId -ne 0){
                $runs = $runs | Where-Object {$_.backupRun.jobRunId -lt $lastRunId}
            }
            foreach($run in $runs){
                $runStartTime = usecsToDate $run.backupRun.stats.startTimeUsecs
                "    {0}" -f $runStartTime
                """{0}"",""{1}""" -f $job.name, $runStartTime | Out-File -FilePath $outfileName -Append 
            }
            if(!$runs -or $runs.Count -eq 0 -or $runs[-1].backupRun.jobRunId -eq $lastRunId){
                break
            }else{
                $lastRunId = $runs[-1].backupRun.jobRunId
                $endUsecs = $runs[-1].backupRun.stats.endTimeUsecs
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
