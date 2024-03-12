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
    [Parameter()][string]$clusterName = $null,
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "mediaInfo-$($cluster.name)-$dateString.csv"
"""Cluster Name"",""Protection Group"",""Start Time"",""Target"",""Barcode"",""Location"",""Online""" | Out-File -FilePath $outfileName -Encoding utf8

if($daysBack){
    $daysAgoUsecs = timeAgo $daysBack days
}

$nowUsecs = dateToUsecs (Get-Date)
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true"
foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    Write-Host $job.name
    $endUsecs = $nowUsecs
    while($True){
        $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&archivalRunStatus=Succeeded&endTimeUsecs=$endUsecs&excludeNonRestoreableRuns=true"
        foreach($run in $runs.runs){
            if($daysBack -and $run.localBackupInfo.startTimeUsecs -lt $daysAgoUsecs){
                $runs.runs = @()
                break
            }
            $runStartTime = usecsToDate $run.localBackupInfo.startTimeUsecs
            foreach($archive in $run.archivalInfo.archivalTargetResults){
                $tid = $archive.archivalTaskId -split ':'
                if($archive.targetType -eq 'Tape' -and $archive.status -eq 'Succeeded' -and $archive.expiryTimeUsecs -gt $nowUsecs){
                    $archiveMediaInfo = api get "vaults/archiveMediaInfo?clusterId=$($tid[0])&clusterIncarnationId=$($tid[1])&qstarArchiveJobId=$($tid[2])"
                    foreach($info in $archiveMediaInfo){
                        Write-Host "    $runStartTime    $($info.barcode) $($info.location) $($info.online)"
                        """$($cluster.name)"",""$($job.name)"",""$runStartTime"",""$($archive.targetName)"",""$($info.barcode)"",""$($info.location)"",""$($info.online)""" | Out-File -FilePath $outfileName -Encoding utf8 -Append
                    }
                }
            }
        }
        if($runs.runs.Count -eq $numRuns){
            $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
        }else{
            break
        }
    }
}

Write-Host "`nOutput saved to $outfilename`n"
