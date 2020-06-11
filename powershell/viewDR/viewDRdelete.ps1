 ### usage: ./viewDRdelete.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$viewName,
    [Parameter()][string]$viewList,
    [Parameter()][switch]$all,
    [Parameter()][string]$inPath,
    [Parameter()][switch]$deleteSnapshots
)

# gather view list
if($viewList){
    $myviews = get-content $viewList
}elseif($viewName){
    $myviews = @($viewName)
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
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

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

"Gathering Views..."
$views = getViews

$confirmed = $false

foreach($viewname in $myviews){
    $view = $views | Where-Object { $_.name -ieq $viewname }
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
            if($view.viewProtection){
                "deleting protection job $($view.viewProtection.protectionJobs[0].jobName)..."
                if($deleteSnapshots){
                    $null = api delete "protectionJobs/$($view.viewProtection.protectionJobs[0].jobId)" @{'deleteSnapshots' = $True}
                }else{
                    $null = api delete "protectionJobs/$($view.viewProtection.protectionJobs[0].jobId)"
                }
                "Deleting $viewname"
                $null = api delete "views/$viewname"
            }
        }
    }
}
