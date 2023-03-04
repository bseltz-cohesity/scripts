### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][switch]$helios,
    [Parameter()][string]$mcm,
    [Parameter()][string]$username='helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList
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

$views = api get views

# gather view list
if($viewList){
    $myViews = get-content $viewList
}elseif($viewNames){
    $myViews = @($viewNames)
}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

foreach($viewName in $myViews | Sort-Object){
    $view = $views.views | Where-Object name -eq $viewName
    if($view){
        $result = api get -v2 "data-protect/failover/views/$($view.viewId)"
        Write-Host "`n-------------------------------------`n       View Name: $viewName"
        Write-Host "-------------------------------------"
        if($result -and $result.PSObject.Properties['failovers']){
            $result = ($result.failovers | Sort-Object -Property startTimeUsecs)[-1]
            Write-Host "   Failover Type: $($result.type)"
            Write-Host "       StartTime: $(usecsToDate $result.startTimeUsecs)"
            Write-Host "          Status: $($result.status)"
            if($result.replications){
                $lastReplication = ($result.replications | Sort-Object -Property startTimeUsecs)[-1]
                if($lastReplication.status -ne 'Succeeded'){
                    Write-Host "Last Replication: $(usecsToDate $lastReplication.startTimeUsecs) - $($lastReplication.status)"
                }else{
                    Write-Host "Last Replication: $(usecsToDate $lastReplication.startTimeUsecs)"
                }   
            }else{
                if($result.type -eq 'Planned'){
                    Write-Host "Last Replication: *** None ***"
                }else{
                    Write-Host "Last Replication: N/A"
                }
            }
        }
    }else{
        Write-Host "View $viewName not found" -ForegroundColor Yellow
    }
}
""
