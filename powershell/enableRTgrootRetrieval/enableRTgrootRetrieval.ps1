[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][Int64]$days = 1,
    [Parameter()][switch]$disable
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$endDate = (Get-Date).AddDays($days)
$endMsecs = [Int64](dateToUsecs $endDate)/1000

$rtParams = @{
    "enableReverseTunnel" = $true;
    "reverseTunnelEnableEndTimeMsecs" = $endMsecs 
}

if($disable){
    $rtParams.enableReverseTunnel = $false
    "Disabling RT..."
}

$null = api put /reverseTunnel $rtParams

if(!$disable){

    $cluster = api get cluster
    $clusterId = $cluster.id
    $clusterName = $cluster.name
    $clusterDomain = $cluster.domainNames[0]
    $postgres = api get postgres
    $grootNode = $postgres[0].nodeIp
    $grootKey = $postgres[0].defaultPassword

    "`nCluster: $clusterName ($clusterDomain) $clusterId"
    "Groot: $grootNode $grootKey"

    if($cluster.clusterSoftwareVersion -gt "6.5.1b"){
        $accessToken = $null
        while(!$accessToken){
            Start-Sleep 1
            $accessToken = (api put users/linuxSupportUserBashShellAccess @{}).supportUserToken
        }
        "`nRT (expires $endDate):`n$accessToken"
        "`nPostgres Export Command:"
        "./getpgdump651.sh $($clusterName.ToLower()) $clusterId $grootKey $grootNode $accessToken`n"
    }else{
        "`nRT expires: $endDate"
        "`nPostgres Export Command:"
        "./getpgdumpPre651.sh $($clusterName.ToLower()) $clusterId $grootKey $grootNode`n"
    }
}
