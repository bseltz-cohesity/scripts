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
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'MiB'
)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "archiveInventory-$($cluster.name)-$dateString.csv"

# headings
"Job Name,Run Date,External Target,Expiry Date,Physical ($unit)" | Out-File -FilePath $outfileName -Encoding utf8

$nowUsecs = timeAgo 1 second

$jobs = api get -v2 "data-protect/protection-groups?includeTenants=true" # isDeleted=false&isActive=true&

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $endUsecs = dateToUsecs (Get-Date)
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        "{0}" -f $job.name
        while($True){
            $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=false"
            foreach($run in $runs.runs){
                if($run.PSObject.Properties['localBackupInfo']){
                    $runStartTimeUsecs = $run.localBackupInfo.startTimeUsecs
                }else{
                    $runStartTimeUsecs = $run.originalBackupInfo.startTimeUsecs
                }
                if($runStartTimeUsecs -gt 0){
                    $runStartTime = usecsToDate $runStartTimeUsecs
                    if($run.PSObject.Properties['archivalInfo']){
                        foreach($archiveResult in $run.archivalInfo.archivalTargetResults){
                            if($archiveResult.expiryTimeUsecs -gt $nowUsecs){
                                $targetName = $archiveResult.targetName
                                $expiry = usecsToDate $archiveResult.expiryTimeUsecs
                                $physicalTransferred = toUnits $archiveResult.stats.physicalBytesTransferred
                                "    {0} ({1}) -> {2} ({3}) {4} $unit" -f $job.name, $runStartTime, $targetName, $expiry, $physicalTransferred
                                """{0}"",""{1}"",""{2}"",""{3}"",""{4}""" -f $job.name, $runStartTime, $targetName, $expiry, $physicalTransferred | Out-File -FilePath $outfileName -Append 
                            }
                        }
                    }
                }
            }
            if($runs.runs.Count -eq $numRuns){
                if($run.PSObject.Properties['localBackupInfo']){
                    $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
                }else{
                    $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs - 1
                }
            }else{
                break
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
