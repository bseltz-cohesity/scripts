### usage: ./protectView.ps1 -vip bseltzve01 -username admin -viewList ./viewlist.txt -policyName 'Standard Protection'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$viewList, #name of VM to protect
    [Parameter(Mandatory = $True)][string]$policyName, #name of the job to add VM to
    [Parameter()][switch]$paused
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster info
$clusterName = (api get cluster).name

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
    $view = $views | Where-Object { $_.name -ieq $viewName }
    if(!$view){
        Write-Warning "View $viewName not found. Skipping!"
        continue
    }
    
    $protectionJob = @{
        'name' = "$clusterName $($view.name) backup";
        'environment' = 'kView';
        '_envParams' = @{};
        'viewBoxId' = $view.viewBoxId;
        'sourceIds' = @();
        'excludeSourceIds' = @();
        'vmTagIds' = @();
        'excludeVmTagIds' = @();
        '_selectedSources' = @();
        'policyId' = $policy.id;
        'priority' = 'kMedium';
        'alertingPolicy' = @(
            'kFailure'
        );
        'timezone' = 'America/New_York';
        'incrementalProtectionSlaTimeMins' = 60;
        'fullProtectionSlaTimeMins' = 120;
        'qosType' = 'kBackupHDD';
        '_sourceSpecialParametersMap' = @{};
        'viewName' = $view.name;
        '_viewBoxName' = $view.viewBoxName;
        '_viewSource' = @{
            'name' = $view.name;
            'viewProtectionSource' = @{
                'id' = @{
                    'id' = $view.viewId;
                }
            }
        };
        'isActive' = $true;
        '_parentSource' = @{};
        '_supportsAutoProtectExclusion' = $false;
        'sourceSpecialParameters' = @();
        'isDeleted' = $true;
        '_supportsIndexing' = $false;
        'indexingPolicy' = @{
            'disableIndexing' = $true
        };
        '_hasFilePathFilters' = $false;
        'startTime' = @{
            'hour' = 23;
            'minute' = 55;
        }
    }


    
    "Creating Protection Job for $($view.name)..."
    $newJob = api post protectionJobs $protectionJob
    if($paused){
         $null = api post protectionJobState/$($newJob.id) @{ "pause" = $True; "pauseReason" = 0 }
    }
}


