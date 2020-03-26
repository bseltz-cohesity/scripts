### usage: ./viewDRdeleteAll.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$viewName,
    [Parameter()][string]$viewList
)

# gather view list
if($viewList){
    $views = get-content $viewList
}elseif($viewName){
    $views = @($viewName)
}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$confirmed = $false

foreach($viewname in $views){
    $view = api get "views/$viewname"
    if($view){
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
                $null = api delete "protectionJobs/$($view.viewProtection.protectionJobs[0].jobId)"
            }
            "Deleting $viewname"
            $null = api delete "views/$viewname"
        }
    }
}
