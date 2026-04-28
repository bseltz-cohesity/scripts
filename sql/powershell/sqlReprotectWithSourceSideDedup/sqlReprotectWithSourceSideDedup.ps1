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
    [Parameter()][string]$newStorageDomainName,
    [Parameter()][string]$newPolicyName,
    [Parameter()][switch]$pauseNewJob
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

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -lt '7.3.1'){
    Write-Host "This script requires Cohesity version 7.3.1 or later" -ForegroundColor Yellow
    exit
}

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $True)

$jobs = api get -v2 'data-protect/protection-groups?isActive=true'

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

if($newStorageDomainName){
    $newStorageDomain = api get viewBoxes | Where-Object name -eq $newStorageDomainName
    if(!$newStorageDomain){
        Write-Host "Storage Domain $newStorageDomainName not found" -ForegroundColor Yellow
        exit
    }
}

if($newPolicyName){
    $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $newPolicyName
    if(!$newPolicy){
        Write-Host "Policy $newPolicyName not found" -ForegroundColor Yellow
        exit
    }
}

foreach($thisJobName in $jobNames){
    $job = $jobs.protectionGroups | Where-Object name -eq $thisJobName
    if($job.mssqlParams.protectionType -ne 'kFile'){
        Write-Host "$($job.name) is not a file based SQL protection group. Skipping" -ForegroundColor Yellow
        continue
    }
    
    # save JSON just in case
    $job | toJson | Out-File -FilePath "$($job.name).json"
    
    # set new storage domain
    if($newStorageDomainName){
        $job.storageDomainId = $newStorageDomain.id
    }

    # apply new policy
    if($newPolicyName){
        $job.policyId = $newPolicy.id
    }

    # pause new job
    if($pauseNewJob){
        $job.isPaused = $True
    }else{
        $job.isPaused = $false
    }

    # enable source side dedup
    $job.mssqlParams.fileProtectionTypeParams.performSourceSideDeduplication = $True

    Write-Host "Recreating: $($job.name)"
    # delete old job
    $deljob = api delete -v2 data-protect/protection-groups/$($job.id)

    # create new job
    $newjob = api post -v2 data-protect/protection-groups $job
}
