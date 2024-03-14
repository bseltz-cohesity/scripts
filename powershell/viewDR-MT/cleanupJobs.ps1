### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -tenant $tenant

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

# # gather view list
if($viewList){
    $myViews = get-content $viewList
}elseif($viewNames){
    $myViews = @($viewNames)
}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

# delete old empty jobs from target cluster
$jobs = api get -v2 "data-protect/protection-groups?isActive=true&isPaused=true&environments=kView"
foreach($job in $jobs.protectionGroups){
    if($null -eq $job.viewParams.objects){
        Write-Host "Deleting old job $($job.name)"
        $null = api delete -v2 data-protect/protection-groups/$($job.id)
    }
}

# delete old remote jobs
$jobs = api get -v2 "data-protect/protection-groups?isActive=false&environments=kView"
foreach($job in $jobs.protectionGroups){
    $deleteJob = $False
    foreach($viewName in $myViews){
        $viewName = [string]$viewName
        if($viewName -in $job.viewParams.objects.name){
            $deleteJob = $True
        }
    }
    if($deleteJob){
        Write-Host "Deleting old job $($job.name)"
        $null = api delete -v2 data-protect/protection-groups/$($job.id)
    }
}

# rename new jobs
$jobs = api get -v2 "data-protect/protection-groups?isActive=true&environments=kView"
foreach($job in $jobs.protectionGroups){
    $newJobName = ($job.name -replace "^failover_", "" -replace "^failover-", "")
    if($newJobName -ne $jobName){
        Write-Host "Renaming job $($job.name) -> $($newJobName)"
        $job.name = $newJobName
        $null = api put -v2 data-protect/protection-groups/$($job.id) $job
    }
}
