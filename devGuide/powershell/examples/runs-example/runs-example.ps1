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
$outfileName = "baseV2-$($cluster.name)-$dateString.csv"

# headings
"""Job Name"",""Run Date"",""Status""" | Out-File -FilePath $outfileName

# get the list of protection groups
$jobs = api get -v2 "data-protect/protection-groups?includeTenants=true"

# for each protection group, get the group's runs
foreach($job in $jobs.protectionGroups | Sort-Object -Property name){

    # start at today
    $endUsecs = dateToUsecs (Get-Date)

    # track the last run we saw
    $lastRunId = 0

    while($True){

        # get $numRuns runs in reverse chronological order  
        $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true"
        if($lastRunId -ne 0){
            # skip runs we already saw
            $runs.runs = $runs.runs | Where-Object {$_.id -lt $lastRunId}
        }

        # process runs
        foreach($run in $runs.runs){
            if($run.PSObject.Properties['localBackupInfo']){
                # local backup
                $runStartTime = usecsToDate $run.localBackupInfo.startTimeUsecs
                $status = $run.localBackupInfo.status
            }elseif($run.PSObject.Properties['originalBackupInfo']){
                # replicated backup
                $runStartTime = usecsToDate $run.originalBackupInfo.startTimeUsecs
                $status = $run.originalBackupInfo.status
            }else{
                # archive direct backup
                $runStartTime = usecsToDate $run.archivalInfo.archivalTargetResults[0].startTimeUsecs
                $status = $run.archivalInfo.archivalTargetResults[0].status
            }
            
            # output to the screen
            "    {0}`t{1}" -f $runStartTime, $status

            # output to the CSV file
            """{0}"",""{1}"",""{2}"",""{3}""" -f $job.name, $runStartTime, $status | Out-File -FilePath $outfileName -Append 
        }

        if(!$runs.runs -or $runs.runs.Count -eq 0 -or $runs.runs[-1].id -eq $lastRunId){
            # if there are no runs then we are done
            break
        }else{

            # update the last run we saw, and update $endUsecs so the next loop gets the next page of runs
            $lastRunId = $runs.runs[-1].id
            if($runs.runs[-1].PSObject.Properties['localBackupInfo']){
                # local backup
                $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs
            }elseif($runs.runs[-1].PSObject.Properties['originalBackupInfo']){
                # replicated backup
                $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs
            }else{
                # archive direct backup
                $endUsecs = $runs.runs[-1].archivalInfo.archivalTargetResults[0].endTimeUsecs
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
