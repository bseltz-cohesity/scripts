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
    [Parameter()][string]$jobName,
    [Parameter(Mandatory=$True)][string]$objectName
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

$jobs = api get -v2 "data-protect/protection-groups?isActive=true&isDeleted=false&pruneSourceIds=true&pruneExcludedSourceIds=true"
if($jobName){
    $jobs.protectionGroups = $jobs.protectionGroups | Where-Object name -eq $jobName
}
if($jobs.protectionGroups.Count -gt 0){
    foreach($job in $jobs.protectionGroups){
        $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?localBackupRunStatus=Running&includeObjectDetails=true"
        if($runs.runs.Count -gt 0){
            foreach($run in $runs.runs){
                $localTaskId = $run.localBackupInfo.localTaskId
                $object = $run.objects | Where-Object {$_.object.name -eq $objectName}
                if($object){
                    $cancelParams = @{
                        "action" = "Cancel";
                        "cancelParams" = @(
                            @{
                                "runId" = $run.id;
                                "localTaskId" = $localTaskId;
                                "objectIds" = @(
                                    $object.object.id
                                )
                            }
                        )
                    }
                    Write-Host "Canceling $($job.name) run for $objectName"
                    $cancel = api post -v2 "data-protect/protection-groups/$($job.id)/runs/actions" $cancelParams
                }
            }
        }
    }
}else{
    Write-Host "Protection group $jobName not found" -ForegroundColor Yellow
    exit
}
