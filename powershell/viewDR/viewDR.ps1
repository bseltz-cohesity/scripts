### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter()][switch]$all,
    [Parameter()][switch]$prepareForFailover,
    [Parameter()][switch]$plannedFailover,
    [Parameter()][switch]$unplannedFailover,
    [Parameter()][switch]$noReplication
)

if($noReplication){
    $reverseReplication = $false
}else{
    $reverseReplication = $True
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -tenant $tenant

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$jobs = api get "protectionJobs?environments=kView&isActive=false"
$views = api get views

# gather view list
if(! $all){
    if($viewList){
        $myViews = get-content $viewList
    }elseif($viewNames){
        $myViews = @($viewNames)
    }else{
        Write-Host "No Views Specified" -ForegroundColor Yellow
        exit
    }
}else{
    $myViews = @($jobs.remoteViewName | Sort-Object -Unique)
}

if($prepareForFailover){
    $action = "Initiating pre-failover replication"
    $params = @{
        "type" = "Planned";
        "plannedFailoverParams" = @{
            "type" = "Prepare";
            "preparePlannedFailverParams" = @{
                "reverseReplication" = $reverseReplication
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
            "reverseReplication" = $reverseReplication
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
        $null = api post -v2 "data-protect/failover/views/$($view.viewId)" $params
        # update migratedshares list
        "$viewName" | Out-File -FilePath $migratedShares -Append
        foreach($alias in $view.aliases){
            "$($alias.aliasName)" | Out-File -FilePath $migratedShares -Append
        }
    }else{
        Write-Host "View $viewName not found" -ForegroundColor Yellow
    }
}
