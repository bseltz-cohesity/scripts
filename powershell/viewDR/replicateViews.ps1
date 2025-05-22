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
    [Parameter()][string]$viewList,
    [Parameter()][int64]$waitMinutesIfRunning = 5,      # give up and exit if existing run is still running
    [Parameter()][int64]$sleepTimeSecs = 30             # sleep seconds between status queries
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

$views = api get -v2 "file-services/views?viewProtectionTypes=ReplicationOut&useCachedData=false&maxCount=2000&includeTenants=false&includeStats=false&includeProtectionGroups=true&includeInactive=false"

$views = $views.views | Where-Object {$_.name -in $myViews}
$protectionGroups = @($views.viewProtection.protectionGroups.groupName | Sort-Object -Unique)

$jobs = api get -v2 "data-protect/protection-groups?isActive=true&environments=kView"
foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $runJob = $False
    if($job.name -in @($protectionGroups)){
        $runJob = $True
    }
    foreach($viewName in $myViews){
        $viewName = [string]$viewName
        if($viewName -in @($job.viewParams.objects.name)){
            $runJob = $True
        }
    }
    if($runJob -eq $True){
        $jobName = $job.name
        $clusterId, $clusterIncarnationId, $v1JobId = $job.id -split ':'
        $v1JobId = [int64] $v1JobId
        $v2JobId = $job.id
        $policyId = $job.policyId
        $policy = api get "protectionPolicies/$policyId"
        $copyRunTargets = @()
        # add replication params
        if($policy.PSObject.Properties['snapshotReplicationCopyPolicies'] -and (! $replicateTo)){
            foreach($replica in $policy.snapshotReplicationCopyPolicies){
                if(!($copyRunTargets | Where-Object {$_.replicationTarget.clusterName -eq $replica.target.clusterName})){
                    $copyRunTargets = $copyRunTargets + @{
                        "daysToKeep"        = $replica.daysToKeep;
                        "replicationTarget" = $replica.target;
                        "type"              = "kRemote"
                    }
                }
            }
        }
        $jobdata = @{
            "runType" = 'kRegular'
            "copyRunTargets" = $copyRunTargets
            "usePolicyDefaults" = $True
        }
        # get last run id
        $runs = api get -v2 "data-protect/protection-groups/$v2JobId/runs?numRuns=1&includeObjectDetails=false"
        if($null -ne $runs -and $runs.PSObject.Properties['runs']){
            $runs = @($runs.runs)
        }

        if($null -ne $runs -and $runs.Count -ne "0"){
            $newRunId = $lastRunId = $runs[0].protectionGroupInstanceId
        }
        # run job
        $result = api post ('protectionJobs/run/' + $v1JobId) $jobdata # -quiet
        $reportWaiting = $True
        $now = Get-Date
        $waitUntil = $now.AddMinutes($waitMinutesIfRunning)
        while($result -ne ""){
            if((Get-Date) -gt $waitUntil){
                Write-Host "Timed out waiting for existing run to finish" -ForegroundColor Yellow
                if($extendedErrorCodes){
                    exit 4
                }else{
                    exit 1
                }
            }
            if($reportWaiting){
                Write-Host "Waiting for existing job run to finish..."
                $reportWaiting = $false
            }
            Start-Sleep $sleepTimeSecs
            $result = api post ('protectionJobs/run/' + $v1JobId) $jobdata -quiet
        }
        Write-Host "Running $jobName..."
    }
}

