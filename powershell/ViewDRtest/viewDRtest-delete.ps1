 ### usage: ./viewDRdelete.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter(Mandatory = $True)][string]$suffix,
    [Parameter()][switch]$deleteSnapshots,
    [Parameter()][switch]$force
)

# gather view list
if($viewList){
    $myViews = get-content $viewList
}elseif($viewNames){
    $myViews = @($viewNames)
}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
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

### get views
function getViews(){
    $myViews = @()
    $views = api get "views"
    $myViews += $views.views
    $lastResult = $views.lastResult
    while(! $lastResult){
        $lastViewId = $views.views[-1].viewId
        $views = api get "views?maxViewId=$lastViewId"
        $lastResult = $views.lastResult
        $myViews += $views.views
    }
    return $myViews
}

$cluster = api get cluster

$confirmed = $false
if($force){
    $confirmed = $True
}

foreach($viewName in $myviews){
    $viewName = "$($viewName)-$($suffix)"
    $views = api get views?viewNames=$viewName
    $view = $views.views | Where-Object { $_.name -ieq "$viewName" }
    if($view){
        $view = $view[0]
        if($confirmed -eq $false){
            write-host "***********************************************" -ForegroundColor Red
            write-host "*** Warning: you are about to delete views! ***" -ForegroundColor Red
            write-host "***********************************************" -ForegroundColor Red
            $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
            if($confirm.ToLower() -eq 'yes'){
                $confirmed = $True
            }else{
                "Canceling..."
                exit
            }
        }
        if($confirmed -eq $True){
            if($view.viewProtection){
                $jobName = $view.viewProtection.protectionJobs[0].jobName
                $jobId = $view.viewProtection.protectionJobs[0].jobId
                $v2JobId = "{0}:{1}:{2}" -f $cluster.id, $cluster.incarnationId, $jobId
                $job = api get -v2 data-protect/protection-groups/$v2JobId
                $job.viewParams.objects = @($job.viewParams.objects | Where-Object {$_.id -ne $view.viewId})
                $job.viewParams.objects = @($job.viewParams.objects | Where-Object {$_.id -in $views.viewId})
                $job.viewParams.replicationParams.viewNameConfigList = @($job.viewParams.replicationParams.viewNameConfigList | Where-Object { $_.sourceViewId -ne $view.viewId})
                $job.viewParams.replicationParams.viewNameConfigList = @($job.viewParams.replicationParams.viewNameConfigList | Where-Object { $_.sourceViewId -in $views.viewId})
                if($job.viewParams.objects.Count -gt 0){
                    $job = api put -v2 data-protect/protection-groups/$v2JobId $job
                    Start-Sleep 3
                }else{
                    "deleting protection job $($view.viewProtection.protectionJobs[0].jobName)..."
                    if($deleteSnapshots){
                        $null = api delete "protectionJobs/$($view.viewProtection.protectionJobs[0].jobId)" @{'deleteSnapshots' = $True}
                    }else{
                        $null = api delete "protectionJobs/$($view.viewProtection.protectionJobs[0].jobId)"
                    }
                }
                
                "deleting view $viewName"
                $null = api delete "views/$viewName"
                $views = $views | Where-Object {$_.name  -ne $viewName}
            }else{
                if(! $all){
                    "deleting view $viewName"
                    $null = api delete "views/$viewName"
                }
            }
        }
    }else{
        Write-Host "View $viewName not found" -ForegroundColor Yellow
    }
}
