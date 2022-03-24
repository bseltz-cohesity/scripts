 ### usage: ./viewDRdelete.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter()][switch]$all,
    [Parameter()][string]$inPath,
    [Parameter()][string]$suffix,
    [Parameter()][switch]$deleteSnapshots
)

# gather view list
if($viewList){
    $myviews = get-content $viewList
}elseif($viewNames){
    $myviews = @($viewNames)
}elseif($all -and $inPath){
    if(test-path $inPath){
        $files = Get-ChildItem $inPath
        $myviews = @()
        foreach($file in $files){
            $myviews += $file.name
        }
    }else{
        Write-Warning "Can't access $inPath"
        exit
    }

}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password -quiet
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password -quiet
}

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

# get/create temp unlock policy
$policy = api get protectionPolicies | Where-Object {$_.name -eq 'ViewDR Temp Unlock Policy'}
if(!$policy){
    $policyParams = @{
        "name" = "ViewDR Temp Unlock Policy";
        "incrementalSchedulingPolicy" = @{
            "periodicity" = "kDaily";
            "dailySchedule" = @{}
        };
        "retries" = 3;
        "retryIntervalMins" = 5;
        "daysToKeep" = 7
    }
    $policy = api post protectionPolicies $policyParams
}

"Gathering Views..."
$views = getViews

$confirmed = $false

foreach($viewName in $myviews){
    $viewName = [string]$viewName + "$suffix"
    $view = $views | Where-Object { $_.name -ieq "$viewName" }
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
                "Cancelling..."
                exit
            }
        }
        if($confirmed -eq $True){
            ""
            if($view.viewProtection){
                "    deleting protection job $($view.viewProtection.protectionJobs[0].jobName)..."
                if($deleteSnapshots){
                    $null = api delete "protectionJobs/$($view.viewProtection.protectionJobs[0].jobId)" @{'deleteSnapshots' = $True}
                }else{
                    $jobId = $view.viewProtection.protectionJobs[0].jobId
                    $v2JobId = "{0}:{1}:{2}" -f $cluster.id, $cluster.incarnationId, $jobId
                    $job = api get -v2 data-protect/protection-groups/$v2JobId
                    $job.policyId = $policy.id
                    $job = api put -v2 data-protect/protection-groups/$v2JobId $job
                    $null = api delete "protectionJobs/$($view.viewProtection.protectionJobs[0].jobId)"
                }
                "    deleting view $viewName"
                $null = api delete "views/$viewName"
            }else{
                if(! $all){
                    "    deleting view $viewName"
                    $null = api delete "views/$viewName"
                }
            }
        }
    }
}
