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
    [Parameter()][string]$viewList,
    [Parameter()][switch]$prepareForFailover,
    [Parameter()][switch]$plannedFailover,
    [Parameter()][switch]$unplannedFailover
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

if($prepareForFailover -or $unplannedFailover){
    $jobs = api get -v2 "data-protect/protection-groups?isActive=false&environments=kView"
    $jobs | ConvertTo-Json -Depth 99 | Out-File "jobs-$($targetCluster).json"
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

if($prepareForFailover){
    $action = "Initiating pre-failover replication"
    $params = @{
        "type" = "Planned";
        "plannedFailoverParams" = @{
            "type" = "Prepare";
            "preparePlannedFailverParams" = @{
                "reverseReplication" = $False
            }
        }
    }
}elseif($plannedFailover){
    $action = "Executing planned failover"
    $params = @{
        "type" = "Planned";
        "plannedFailoverParams" = @{
            "type" = "Finalize";
            "preparePlannedFailverParams" = @{}
        }
    }
}elseif($unplannedFailover){
    $action = "Executing unplanned failover"
    $params = @{
        "type" = "Unplanned";
        "unplannedFailoverParams" = @{
            "reverseReplication" = $False
        }
    }
}else{
    Write-Host "No actions specified. Choose -prepareForFailover, -plannedFailover or -unplannedFailover" -ForegroundColor Yellow
    exit
}

$migratedShares = "migratedShares.txt"
$null = Remove-Item -Path $migratedShares -Force -ErrorAction SilentlyContinue

foreach($viewName in $myViews){
    $view = $views.views | Where-Object name -eq $viewName
    if($view){
        Write-Host "$action for $viewName"
        $result = api post -v2 "data-protect/failover/views/$($view.viewId)" $params
        if($result){
            "$viewName" | Out-File -FilePath $migratedShares -Append
            foreach($alias in $view.aliases){
                "$($alias.aliasName)" | Out-File -FilePath $migratedShares -Append
            }
        }
    }else{
        Write-Host "View $viewName not found" -ForegroundColor Yellow
    }
}

