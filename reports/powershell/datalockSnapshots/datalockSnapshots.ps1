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
    [Parameter()][string]$clusterName = $null,
    [Parameter()][int]$numRuns = 1000
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

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
$outfileName = "datalockSnapshots-$($cluster.name)-$dateString.csv"
$nowUsecs = dateToUsecs

# headings
"Job Name,Tenant,Run Date,Status,DataLock Expiry" | Out-File -FilePath $outfileName -Encoding utf8

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

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $endUsecs = dateToUsecs (Get-Date)
    $lastRunId = 0
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        $tenant = $job.permissions.name
        if($tenant){
            "{0} ({1})" -f $job.name, $job.permissions.name  # tenant
        }else{
            "{0}" -f $job.name
        }
        while($True){
            $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&excludeNonRestorableRuns=true&includeObjectDetails=false"
            if($lastRunId -ne 0){
                $runs.runs = $runs.runs | Where-Object {$_.id -lt $lastRunId}
            }
            foreach($run in $runs.runs){
                if($run.PSObject.Properties['localBackupInfo']){
                    $runStartTime = usecsToDate $run.localBackupInfo.startTimeUsecs
                    $status = $run.localBackupInfo.status
                    $runInfo = $run.localBackupInfo
                }elseif($run.PSObject.Properties['originalBackupInfo']){
                    $runStartTime = usecsToDate $run.originalBackupInfo.startTimeUsecs
                    $status = $run.originalBackupInfo.status
                    $runInfo = $run.originalBackupInfo
                }else{
                    $runStartTime = usecsToDate $run.archivalInfo.archivalTargetResults[0].startTimeUsecs
                    $status = $run.archivalInfo.archivalTargetResults[0].status
                    $runInfo = $run.archivalInfo.archivalTargetResults[0]
                }

                $runStartTime = usecsToDate $runInfo.startTimeUsecs
                $status = $runInfo.status
                $lockExpiry = ''
                if($runInfo.PSObject.Properties['dataLockConstraints'] -and $runInfo.dataLockConstraints.PSObject.Properties['expiryTimeUsecs']){
                    $lockExpiryUsecs = $runInfo.dataLockConstraints.expiryTimeUsecs
                    if($lockExpiryUsecs -gt $nowUsecs){
                        $lockExpiry = usecsToDate $lockExpiryUsecs
                    }
                }
                if($lockExpiry -ne ''){
                    "    {0}`tlock expires: {1}" -f $runStartTime, $lockExpiry
                    """{0}"",""{1}"",""{2}"",""{3}"",""{4}""" -f $job.name, $tenant, $runStartTime, $status, $lockExpiry | Out-File -FilePath $outfileName -Append 
                }
            }
            if(!$runs.runs -or $runs.runs.Count -eq 0 -or $runs.runs[-1].id -eq $lastRunId){
                break
            }else{
                $lastRunId = $runs.runs[-1].id
                $endUsecs = $runInfo.endTimeUsecs
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
