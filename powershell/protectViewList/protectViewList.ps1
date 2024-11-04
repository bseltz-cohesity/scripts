### usage: ./protectView.ps1 -vip bseltzve01 -username admin -viewList ./viewlist.txt -policyName 'Standard Protection'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,             # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,        # username (local or AD)
    [Parameter()][string]$domain = 'local',                 # local or AD domain
    [Parameter(Mandatory = $True)][string]$viewList,        # name of VM to protect
    [Parameter(Mandatory = $True)][string]$policyName,      # name of the job to add VM to
    [Parameter()][switch]$createDRview,                     # create DR view during replication
    [Parameter()][string]$drsuffix = '',                    # apply suffix to DR view name
    [Parameter()][switch]$paused,                           # pause future runs
    [Parameter()][string]$startTime = '20:00',              # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles'  # e.g. 'America/New_York'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster info
$clusterName = (api get cluster).name

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit
}

$policy = api get protectionPolicies | Where-Object { $_.name -ieq $policyName }
if(!$policy){
    Write-Warning "Policy $policyName not found!"
    exit
}

if(Test-Path $viewList -PathType Leaf){
    $viewNames = Get-Content $viewList
}else{
    Write-Warning "File $viewList not found!"
    exit
}

function getViews(){
    $myViews = @()
    $views = api get views
    $myViews += $views.views
    $lastResult = $views.lastResult
    while(! $lastResult){
        $lastViewId = $views.views[-1].viewId
        $views = api get views?maxViewId=$lastViewId
        $lastResult = $views.lastResult
        $myViews += $views.views
    }
    return $myViews
}

$views = getViews

foreach ($viewName in $viewNames){
    $viewName = [string]$viewName
    $view = $views | Where-Object { $_.name -ieq $viewName }
    if(!$view){
        Write-Warning "View $viewName not found. Skipping!"
        continue
    }

    $newJob = @{
        "name"             = "$clusterName $($view.name) Backup";
        "environment"      = "kView";
        "isPaused"         = if($paused){$True}else{$false};
        "policyId"         = $policy.id;
        "priority"         = "kMedium";
        "storageDomainId"  = $view.viewBoxId;
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
                "enableIndexing" = $true;
                "includePaths"   = @(
                    "/"
                );
                "excludePaths"   = @()
            };
            "objects"           = @(
                @{
                    "id" = $view.viewId
                }
            )
        }
    }

    if($createDRview){
        $drViewName = $viewName
        if($drsuffix -ne ''){
            if($drViewName.EndsWith('$')){
                $drViewName = "{0}{1}$" -f $drViewName.TrimEnd('$'), $drsuffix
            }else{
                $drViewName = "{0}{1}" -f $drViewName.TrimEnd('$'), $drsuffix
            }
        }
        $newJob.viewParams["replicationParams"] = @{
            "createView" = $true;
            "viewName"   = $drviewName
        };
    }
    
    "Creating Protection Job for $($view.name)..."
    $null = api post -v2 data-protect/protection-groups $newJob
}


