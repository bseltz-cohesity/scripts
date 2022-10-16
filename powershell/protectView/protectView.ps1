### usage: ./protectVMs.ps1 -vip bseltzve01 -username admin -jobName 'vm backup' -vmName mongodb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$viewName,  # names of Views to protect
    [Parameter()][string]$viewList = '',  # text file of view names to protect
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add VM to
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][switch]$disableIndexing,
    [Parameter()][string]$drSuffix = ''
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
            exit 1
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit 1
    }
    return ($items | Sort-Object -Unique)
}

$viewsToAdd = @(gatherList -Param $viewName -FilePath $viewList -Name 'views' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -lt '6.6' -and $viewsToAdd.Count -gt 1){
    Write-Host "Cohesity versions prior to 6.6 can only protect one view per job" -ForegroundColor Yellow
    exit 1
}

$views = api get -v2 file-services/views

# get the protectionJob
$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}

if($job){

    # existing protection job
    $newJob = $false
    if($job.environment -ne 'kView'){
        Write-host "Job $jobName exists but is not a view protection job" -ForegroundColor Yellow
        exit 1
    }
    if($cluster.clusterSoftwareVersion -lt '6.6'){
        Write-Host "Job $jobName already exists. Only one view allowed per job" -ForegroundColor Yellow
        exit 1
    }

}else{

    # new protection group
    $newJob = $True

    if($paused){
        $isPaused = $True
    }else{
        $isPaused = $false
    }

    if($disableIndexing){
        $enableIndexing = $false
    }else{
        $enableIndexing = $True
    }

    # get policy
    if(!$policyName){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit 1
    }else{
        $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
        if(!$policy){
            Write-Host "Policy $policyName not found" -ForegroundColor Yellow
            exit 1
        }
    }

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit 1
    }

    $job = @{
        "name"             = $jobName;
        "environment"      = "kView";
        "isPaused"         = $isPaused;
        "policyId"         = $policy.id;
        "priority"         = "kMedium";
        "storageDomainId"  = 0;
        "description"      = "";
        "startTime"        = @{
            "hour"     = [int]$hour;
            "minute"   = [int]$minute;
            "timeZone" = $timeZone
        };
        "abortInBlackouts" = $false;
        "alertPolicy"      = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets"    = @()
        };
        "sla"              = @(
            @{
                "backupRunType" = "kFull"
            };
            @{
                "backupRunType" = "kIncremental"
            }
        );
        "viewParams"       = @{
            "indexingPolicy"    = @{
                "enableIndexing" = $enableIndexing;
                "includePaths"   = @(
                    "/"
                );
                "excludePaths"   = @()
            };
            "objects"           = @()
        }
    }
    if($policy.PSObject.Properties['remoteTargetPolicy'] -and $policy.remoteTargetPolicy.PSObject.Properties['replicationTargets']){
        if($cluster.clusterSoftwareVersion -lt '6.6'){
            $job.viewParams['replicationParams'] = @{}
        }else{
            $job.viewParams['replicationParams'] = @{
                "viewNameConfigList" = @()
            }
        }
    }
    $job = $job | ConvertTo-JSON -Depth 99 | ConvertFrom-JSON
}

foreach($thisViewName in $viewsToAdd){

    $thisView = $views.views | Where-Object {$_.name -eq $thisViewName}
    if(! $thisView){
        Write-Host "View $thisViewName not found" -ForegroundColor Yellow
        exit 1
    }else{
        if($job.storageDomainId -eq 0){
            $job.storageDomainId = $thisView.storageDomainId
        }elseif($job.storageDomainId -ne $thisView.storageDomainId){
            Write-Host "View $thisViewName is in a different storage domain than the protection job $($job.name). Skipping..." -ForegroundColor Yellow
            continue
        }
        $job.viewParams.objects = @(@($job.viewParams.objects | Where-Object {$_.id -ne $thisView.viewId}) + @{"id" = $thisView.viewId})
        if($job.viewParams.PSObject.Properties['replicationParams']){
            $drViewName = $thisViewName
            $useSameViewName = $True
            if($drSuffix -ne ''){
                $drViewName = "$drViewName-$drSuffix"
                $useSameViewName = $false
            }
            if($cluster.clusterSoftwareVersion -lt '6.6'){
                $job.viewParams.replicationParams = @{
                    "createView" = $True;
                    "viewName" = $drViewName
                }
            }else{
                $job.viewParams.replicationParams.viewNameConfigList = @(@($job.viewParams.replicationParams.viewNameConfigList | Where-Object {$_.viewName -ne $drViewName}) + @{
                    "sourceViewId" = $thisView.viewId;
                    "useSameViewName" = $useSameViewName;
                    "viewName" = $drViewName
                })
            }
        }
    }
}

if($newJob){
    "Creating protection job $jobName"
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    "Updating protection job $($job.name)"
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
