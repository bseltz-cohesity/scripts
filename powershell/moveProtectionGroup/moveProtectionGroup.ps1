# process commandline arguments
[CmdletBinding(PositionalBinding=$false)]
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
    [Parameter()][string]$clusterName,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][switch]$deleteOldJob,
    [Parameter()][switch]$renameOldJob,
    [Parameter(Mandatory = $True)][string]$newStorageDomainName,
    [Parameter()][string]$newPolicyName,
    [Parameter()][switch]$pauseNewJob,
    [Parameter()][switch]$pauseOldJob
)


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


if($prefix -eq '' -and $suffix -eq '' -and !$deleteOldJob){
    Write-Host "You must use either -prefix or -suffix or -deleteOldJob" -foregroundcolor Yellow
    exit
}

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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $True)

$jobs = api get -v2 'data-protect/protection-groups?isActive=true'
$newStorageDomain = api get viewBoxes | Where-Object name -eq $newStorageDomainName
if($newPolicyName){
    $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $newPolicyName
    if(!$newPolicy){
        Write-Host "Policy $newPolicyName not found" -ForegroundColor Yellow
        exit
    }
}

if(!$newStorageDomain){
    Write-Host "Storage Domain $newStorageDomainName not found" -ForegroundColor Yellow
    exit
}

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit
    }
}

foreach($thisJobName in $jobNames){
    $job = $jobs.protectionGroups | Where-Object name -eq $thisJobName
    if($job.Count -gt 1){
        Write-Host "There is more than one job with the name $thisJobName, please rename one of them" -foregroundcolor Yellow
        exit
    }
}

foreach($thisJobName in $jobNames){
    $job = $jobs.protectionGroups | Where-Object name -eq $thisJobName
    $originalJobName = $job.name
    if($pauseOldJob -and !$deleteOldJob){
        $job.isPaused = $True
    }

    if($renameOldJob){
        if($prefix -ne ''){
            $job.name = "$($prefix)-$($job.name)"
        }
        if($suffix -ne ''){
            $job.name = "$($job.name)-$($suffix)"
        }
    }
    if(! $deleteOldJob){
        $updateJob = api put -v2 data-protect/protection-groups/$($job.id) $job
    }

    $job.name = $originalJobName
    $job.storageDomainId = $newStorageDomain.id

    if($newPolicyName){
        $job.policyId = $newPolicy.id
    }

    "Moving protection group $($job.name) to $newStorageDomainName..."

    if($pauseNewJob){
        $job.isPaused = $True
    }else{
        $job.isPaused = $false
    }

    if(! $renameOldJob){
        if($prefix -ne ''){
            $job.name = "$($prefix)-$($job.name)"
        }
    
        if($suffix -ne ''){
            $job.name = "$($job.name)-$($suffix)"
        }
    }

    if($deleteOldJob){
        $deljob = api delete -v2 data-protect/protection-groups/$($job.id)
    }

    $newjob = api post -v2 data-protect/protection-groups $job
}
