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
    [Parameter()][string]$viewList
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# gather view list
if($viewList){
    $myViews = get-content $viewList
}elseif($viewNames){
    $myViews = @($viewNames)
}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

# connect to source cluster to fix the remote view name in the source job
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

$oldRemoteViewNames = @()

# update jobs
$jobs = api get -v2 "data-protect/protection-groups?isActive=true&isDeleted=false&environments=kView"
foreach($job in $jobs.protectionGroups){
    $updateJob = $False
    foreach($viewName in $myViews){
        $viewName = [string]$viewName
        $view = $views.views | Where-Object name -eq $viewName
        if($view){
            if($view.viewId -in @($job.viewParams.objects.id)){
                $remoteView = $job.viewParams.replicationParams.viewNameConfigList | Where-Object {$_.sourceViewId -eq $view.viewId}
                if($remoteView -and $remoteView.useSameViewName -eq $False){
                    $updateJob = $True
                    $oldRemoteViewNames = @($oldRemoteViewNames + $remoteView.viewName)
                }
                $job.viewParams.replicationParams.viewNameConfigList = @($job.viewParams.replicationParams.viewNameConfigList | Where-Object {$_.sourceViewId -ne $view.viewId})
                $job.viewParams.replicationParams.viewNameConfigList = @($job.viewParams.replicationParams.viewNameConfigList + @{'sourceViewId' = $view.viewId; 'useSameViewName' = $True})
            }
        }else{
            Write-Host "View $viewName not found" -ForegroundColor Yellow
        }
    }
    if($updateJob -eq $True){
        Write-Host "Updating job $($job.name)"
        $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
    }
}

# connect to target cluster and delete the old remote views
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

# delete old remote views from target cluster
foreach($viewName in $oldRemoteViewNames){
    $viewName = [string]$viewName
    $view = $views.views | Where-Object name -eq $viewName
    if($view){
        if($view.isReadOnly -ne $True){
            Write-Host "View $viewName is live. Skipping..." -ForegroundColor Yellow
        }else{
            Write-Host "Deleting old remote view $viewName"
            $null = api delete views/$viewName
        }
    }else{
        Write-Host "View $viewName not found" -ForegroundColor Yellow
    }
}

