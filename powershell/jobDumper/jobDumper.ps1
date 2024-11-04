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
    [Parameter()][string]$clusterName,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][string]$environment,
    [Parameter()][switch]$includeSources
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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $False)

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

# find specified jobs
$jobs = api get -v2 "data-protect/protection-groups?isActive=true&isDeleted=false"

if($environment){
    $jobs.protectionGroups = $jobs.protectionGroups | Where-Object {$_.environment -eq $environment}
}

# report missing jobs
if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found:`n    $($notfoundJobs -join "`n    ")" -ForegroundColor Yellow
        exit 1
    }
}

$jobs = $jobs.protectionGroups

if($jobNames){
    $jobs = $jobs | Where-Object name -in $jobNames
}

$cluster = api get cluster
$jobsFileName = join-path -Path $PSScriptRoot -ChildPath "$($cluster.name)-jobs.json"
$jobs | ConvertTo-Json -Depth 99 | Out-File -FilePath $jobsFileName
"`nJobs saved to $jobsFileName`n"

if($includeSources){
    $environments = @($jobs.environment | Sort-Object -Unique) -join ','
    $sources = api get "protectionSources?environments=$environments&pruneAggregationInfo=true&pruneNonCriticalInfo=true"
    $sourcesFileName = join-path -Path $PSScriptRoot -ChildPath "$($cluster.name)-sources.json"
    $sources | ConvertTo-Json -Depth 99 | Out-File -FilePath $sourcesFileName
    "Sources saved to $sourcesFileName`n"
}
