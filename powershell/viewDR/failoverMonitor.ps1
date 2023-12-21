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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList
)

# source the cohesity-api helper code
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
            # $result.failovers | fl
            $result = ($result.failovers | Sort-Object -Property startTimeUsecs)[-1]
            Write-Host "   Failover Type: $($result.type)"
            Write-Host "       StartTime: $(usecsToDate $result.startTimeUsecs)"
            Write-Host "          Status: $($result.status)"
            if($result.replications){
                # $result.replications | fl
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
            if($result.PSObject.Properties['errorMessage']){
                Write-Host "           Error:`n$($result.errorMessage)"
            }
        }
    }else{
        Write-Host "View $viewName not found" -ForegroundColor Yellow
    }
}
""
