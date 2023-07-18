### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter()][switch]$plannedFailoverStart,
    [Parameter()][switch]$plannedFailoverFinalize,
    [Parameter()][switch]$unplannedFailover
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant

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

if($plannedFailoverStart){
    $action = "Initiating pre-failover replication"
    $params = @{
        "type" = "Planned";
        "plannedFailoverParams" = @{
            "type" = "Prepare";
            "preparePlannedFailverParams" = @{
                "reverseReplication" = $True
            }
        }
    }
}elseif($plannedFailoverFinalize){
    $action = "Executing planned failover"
    $params = @{
        "type" = "Planned";
        "plannedFailoverParams" = @{
            "type" = "Finalize";
            "preparePlannedFailverParams" = @{
                "reverseReplication" = $True
            }
        }
    }
}elseif($unplannedFailover){
    $action = "Executing unplanned failover"
    $params = @{
        "type" = "Unplanned";
        "unplannedFailoverParams" = @{
            "reverseReplication" = $True
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
        # Start-Sleep 5
    }else{
        Write-Host "View $viewName not found" -ForegroundColor Yellow
    }
}
