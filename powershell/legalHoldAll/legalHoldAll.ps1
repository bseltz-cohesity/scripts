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
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][array]$jobMatch,
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][switch]$removeHold,
    [Parameter()][switch]$addHold,
    [Parameter()][switch]$showTrue,
    [Parameter()][switch]$showFalse,
    [Parameter()][switch]$pushToReplica,
    [Parameter()][string]$startDate = '',   # Only process runs on or after this date (e.g. '2024-01-01')
    [Parameter()][string]$endDate = ''      # Only process runs on or before this date (e.g. '2024-03-31')
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

# parse and validate optional date range parameters
$filterStartUsecs = $null
$filterEndUsecs   = $null

if($startDate -ne ''){
    try {
        $filterStartUsecs = dateToUsecs ([datetime]::Parse($startDate))
    } catch {
        Write-Host "Invalid -startDate '$startDate'. Use format yyyy-MM-dd." -ForegroundColor Yellow
        exit 1
    }
}
if($endDate -ne ''){
    try {
        # include the full end day by advancing to 23:59:59
        $filterEndUsecs = dateToUsecs ([datetime]::Parse($endDate)) # .AddDays(1).AddSeconds(-1))
    } catch {
        Write-Host "Invalid -endDate '$endDate'. Use format yyyy-MM-dd." -ForegroundColor Yellow
        exit 1
    }
}
if($filterStartUsecs -and $filterEndUsecs -and $filterStartUsecs -gt $filterEndUsecs){
    Write-Host "-startDate must be earlier than -endDate." -ForegroundColor Yellow
    exit 1
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

$jobs = api get "protectionJobs"

$matchJobList = @()
if($jobMatch.Length -gt 0){
    foreach($job in $jobs){
        $includeJob = $false
        foreach($matchString in $jobMatch){
            if($job.name -match $matchString){
                $includeJob = $True
            }
        }
        if($includeJob -eq $True){
            $matchJobList += $job
        }
    }
    $jobs = @($matchJobList)
}

# catch invalid job names
if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$cluster = api get cluster
$clusterCreatedUsecs = $cluster.createdTimeMsecs * 1000
if(! $filterStartUsecs){
    $filterStartUsecs = $clusterCreatedUsecs
}
$nowUsecs = dateToUsecs
$dateString = (Get-Date).ToString('yyyy-MM-dd')
$outfile = "legalHolds-$($cluster.name)-$dateString.csv"
"JobName,RunDate,LegalHold,PastExpiration" | Out-File -FilePath $outfile

if($removeHold){
    $holdValue = $false
}else{
    $holdValue = $True
}

foreach($job in $jobs | Sort-Object -Property name){
    $endUsecs = dateToUsecs (Get-Date)
    if($filterEndUsecs){
        $endUsecs = $filterEndUsecs
    }
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        "{0}" -f $job.name
        while($True){
            $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&startTimeUsecs=$filterStartUsecs&endTimeUsecs=$endUsecs&excludeTasks=true&excludeNonRestoreableRuns=true"
            foreach($run in $runs){
                # apply date range filter
                $runStartUsecs = $run.backupRun.stats.startTimeUsecs
                if($filterStartUsecs -and $runStartUsecs -lt $filterStartUsecs){ continue }
                if($filterEndUsecs   -and $runStartUsecs -gt $filterEndUsecs)  { continue }

                if($addHold -or $removeHold){
                    $runParams = @{
                        "jobRuns" = @(
                            @{
                                "copyRunTargets"    = @();
                                "runStartTimeUsecs" = $run.backupRun.stats.startTimeUsecs;
                                "jobUid"            = $jobUid
                            }
                        )
                    }
                    $update = $false
                    foreach($copyRun in $run.copyRun){
                        if($pushToReplica -or $copyRun.target.type -in @('kLocal', 'kArchival')){
                            if($copyRun.PSObject.Properties['holdForLegalPurpose'] -and $copyRun.holdForLegalPurpose -eq $True){
                                $update = $True
                            }
                            if(($addHold -and $copyRun.expiryTimeUsecs -gt (dateToUsecs)) -or $update -eq $True){
                                $update = $True
                                $copyRunTarget = $copyRun.target
                                setApiProperty -object $copyRunTarget -name "holdForLegalPurpose" -value $holdValue
                                $runParams.jobRuns[0].copyRunTargets += $copyRunTarget
                            }
                        }
                    }
                    if($update -eq $True){
                        if($removeHold){
                            $holdValue = $false
                            "    Removing legal hold from $($job.name): $(usecsToDate $run.backupRun.stats.startTimeUsecs)..."
                        }else{
                            $holdValue = $True
                            "    Adding legal hold to $($job.name): $(usecsToDate $run.backupRun.stats.startTimeUsecs)..."
                        }
                        $thisRun = api get "/backupjobruns?id=$($run.jobId)&exactMatchStartTimeUsecs=$($run.backupRun.stats.startTimeUsecs)"
                        $jobUid = @{
                            "clusterId" = $thisRun.backupJobRuns.protectionRuns[0].backupRun.base.jobUid.clusterId;
                            "clusterIncarnationId" = $thisRun.backupJobRuns.protectionRuns[0].backupRun.base.jobUid.clusterIncarnationId;
                            "id" = $thisRun.backupJobRuns.protectionRuns[0].backupRun.base.jobUid.objectId;
                        }
                        $runParams.jobRuns[0]['jobUid'] = $jobUid
                        $null = api put protectionRuns $runParams
                    }
                }else{
                    $legalHoldState = $false
                    foreach($copyRun in $run.copyRun | Where-Object {$_.target.type -in @('kLocal', 'kArchival')}){
                        if($True -eq $copyRun.holdForLegalPurpose){
                            $legalHoldState = $True
                        }
                    }
                    $runDate = usecsToDate $run.backupRun.stats.startTimeUsecs
                    if((! $showTrue -or $legalHoldState -eq $True) -and (! $showFalse -or $legalHoldState -eq $false)){
                        $wouldBeExpired = $false
                        if($legalHoldState -eq $True){
                            $expiry = ($run.copyRun | Where-Object {$_.target.type -eq 'kLocal'})[0].expiryTimeUsecs
                            if($expiry -lt $nowUsecs){
                                $pastExpiration = $True
                                $expiryDate = usecsToDate $expiry
                            }
                        }
                        if($pastExpiration -eq $True){
                            write-host "    $runDate : LegalHold = $legalHoldState (past expiration: $expiryDate)"
                        }else{
                            write-host "    $runDate : LegalHold = $legalHoldState"
                        }
                        """{0}"",""{1}"",""{2}"",""{3}""" -f $job.name, $runDate, $legalHoldState, $pastExpiration | Out-File -FilePath $outfile -Append
                    }
                }
            }
            if($runs.Count -eq $numRuns){
                $endUsecs = $runs[-1].backupRun.stats.endTimeUsecs - 1
                if($endUsecs -le $filterStartUsecs){
                    break
                }
            }else{
                break
            }
        }
    }
}