### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][switch]$helios,
    [Parameter()][string]$mcm,
    [Parameter()][string]$username='helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter(Mandatory = $True)][string]$policyName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($helios -or $mcm){
    if($mcm){
        $vip = $mcm
    }else{
        $vip = 'helios.cohesity.com'
    }
    apiauth -vip $vip -username $username -domain $domain -helios -password $password
    heliosCluster $targetCluster
}else{
    $vip = $targetCluster
    if($useApiKey){
        apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password
    }
}

$views = api get -v2 file-services/views
$jobs = api get -v2 "data-protect/protection-groups?isActive=true&isPaused=true&environments=kView"

# gather view list
if($viewList){
    $myViews = get-content $viewList
}elseif($viewNames){
    $myViews = @($viewNames)
}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

# delete old remote views from target cluster
# foreach($viewName in $myViews){
#     $viewName = [string]$viewName
#     $view = $views.views | Where-Object name -eq $viewName
#     if($view){
#         if($view.isReadOnly -ne $True){
#             Write-Host "View $viewName is live. Skipping..."
#         }else{
#             Write-Host "Deleting old remote view $viewName"
#             $null = api delete views/$viewName
#         }
#     }
# }

# delete old jobs from target cluster
$jobs = api get -v2 "data-protect/protection-groups?isActive=true&isPaused=true&environments=kView"
foreach($job in $jobs.protectionGroups){
    if($job.viewParams.objects -eq $null){
        Write-Host "Deleting old job $($job.name)"
        $null = api delete -v2 data-protect/protection-groups/$($job.id)
    }
}

# connect to source cluster
if($helios -or $mcm){
    heliosCluster $sourceCluster
}else{
    $vip = $sourceCluster
    if($useApiKey){
        apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password
    }
}

$views = api get -v2 file-services/views

# change policy
$policies = api get -v2 data-protect/policies
$policy = $policies.policies | Where-Object name -eq $policyName
if(!$policy){
    Write-Host "Policy $policyName not found" -ForegroundColor Yellow
    exit
}

# delete temp jobs
$jobs = api get -v2 "data-protect/protection-groups?isActive=true&environments=kView"
foreach($job in $jobs.protectionGroups){
    $updateJob = $False
    foreach($viewName in $myViews){
        $viewName = [string]$viewName
        if($viewName -in $job.viewParams.objects.name){
            $updateJob = $True
            $job.viewParams.objects = @($job.viewParams.objects | Where-Object name -ne $viewName)
        }
    }
    if($job.viewParams.objects -eq $null -or $job.viewParams.objects.Count -eq 0){
        Write-Host "Deleting old job $($job.name)"
        $null = api delete -v2 data-protect/protection-groups/$($job.id)
    }else{
        if($updateJob -eq $True){
            Write-Host "Updating job $($job.name)"
            $null = api put -v2 data-protect/protection-groups/$($job.id) $job
        }
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

# create new jobs
$jobs = get-content "jobs-$($sourceCluster).json" | ConvertFrom-Json
foreach($job in $jobs.protectionGroups){
    $createJob = $False
    $job.policyId = $policy.id
    $newObjects = @()
    $job.viewParams.replicationParams.viewNameConfigList = @()
    foreach($viewName in $myViews){
        $viewName = [string]$viewName
        $view = $views.views | Where-Object name -eq $viewName
        if($view){
            if($viewName -in @($job.viewParams.objects.name)){
                $createJob = $True
                $newObjects = @($newObjects + @{'id' = $view.viewId; 'name' = $view.name})
            }
            $job.viewParams.replicationParams.viewNameConfigList = @($job.viewParams.replicationParams.viewNameConfigList + @{'sourceViewId' = $view.viewId; 'useSameViewName' = $True})
        }else{
            Write-Host "View $viewName not found" -ForegroundColor Yellow
        }
    }
    if($createJob -eq $True){
        Write-Host "Creating job $($job.name)"
        $job.viewParams.objects = $newObjects
        $null = api post -v2 "data-protect/protection-groups" $job
    }
}
