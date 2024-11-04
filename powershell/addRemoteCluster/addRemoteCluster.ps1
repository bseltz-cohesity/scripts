### Usage: ./addRemoteCluster.ps1 -localVip 192.168.1.198 -localUsername admin -remoteVip 10.1.1.202 -remoteUsername admin

### Usage: ./addRemoteCluster.ps1 -localVip 192.168.1.198 `
#                                 -localUsername admin `
#                                 -localStorageDomain DefaultStorageDomain `
#                                 -remoteVip 10.1.1.202 `
#                                 -remoteUsername admin `
#                                 -remoteStorageDomain defaultStorageDomain

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$localVip,      #local cluster to connect to
    [Parameter(Mandatory = $True)][string]$localUsername, #local username
    [Parameter()][string]$localDomain = 'local',          #local user domain name
    [Parameter()][string]$localPassword = $null,
    [Parameter()][string]$localStorageDomain = 'DefaultStorageDomain', #local storage domain
    [Parameter(Mandatory = $True)][string]$remoteVip,      #remote cluster to connect to
    [Parameter(Mandatory = $True)][string]$remoteUsername, #remote username
    [Parameter()][string]$remoteDomain = 'local',          #remote user domain name
    [Parameter()][string]$remotePassword = $null,
    [Parameter()][string]$remoteStorageDomain = 'DefaultStorageDomain', #remote storage domain
    [Parameter()][switch]$remoteAccess # enable remote access
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate with both clusters
apiauth -vip $localVip -username $localUsername -domain $localDomain -password $localPassword
$localCluster = getContext
$localClusterInfo = api get cluster
$localStorageDomainId = (api get viewBoxes | Where-Object { $_.name -eq $localStorageDomain }).id
$localPassword = Get-CohesityAPIPassword -vip $localVip -username $localUsername -domain $localDomain
$localNodeIp = (api get nodes)[0].ip

apiauth -vip $remoteVip -username $remoteUsername -domain $remoteDomain -password $remotePassword
$remoteCluster = getContext
$remoteClusterInfo = api get cluster
$remoteStorageDomainId = (api get viewBoxes | Where-Object { $_.name -eq $remoteStorageDomain }).id
$remotePassword = Get-CohesityAPIPassword -vip $remoteVip -username $remoteUsername -domain $remoteDomain
$remoteNodeIp = (api get nodes)[0].ip

### add remoteCluster as partner on localCluster
$localToRemote = @{
    'name' = $remoteClusterInfo.name;
    'clusterIncarnationId' = $remoteClusterInfo.incarnationId;
    'clusterId' = $remoteClusterInfo.id;
    'remoteIps' = @(
        $remoteNodeIp
    );
    'allEndpointsReachable' = $true;
    'viewBoxPairInfo' = @(
        @{
            'localViewBoxId' = $localStorageDomainId;
            'localViewBoxName' = $localStorageDomain;
            'remoteViewBoxId' = $remoteStorageDomainId;
            'remoteViewBoxName' = $remoteStorageDomain
        }
    );
    'userName' = $remoteUsername;
    'password' = $remotePassword;
    'compressionEnabled' = $true;
    'purposeReplication' = $true;
    'purposeRemoteAccess' = $false
}

### add localCluster as partner on remoteCluster
$remoteToLocal = @{
    'name' = $localClusterInfo.name;
    'clusterIncarnationId' = $localClusterInfo.incarnationId;
    'clusterId' = $localClusterInfo.id;
    'remoteIps' = @(
        $localNodeIp
    );
    'allEndpointsReachable' = $true;
    'viewBoxPairInfo' = @(
        @{
            'localViewBoxId' = $remoteStorageDomainId;
            'localViewBoxName' = $remoteStorageDomain;
            'remoteViewBoxId' = $localStorageDomainId;
            'remoteViewBoxName' = $localStorageDomain
        }
    );
    'userName' = $localUsername;
    'password' = $localPassword;
    'compressionEnabled' = $true;
    'purposeReplication' = $true;
    'purposeRemoteAccess' = $false
}

if($remoteAccess){
    $localToRemote.purposeRemoteAccess = $True
    $remoteToLocal.purposeRemoteAccess = $True
}

### join clusters
Write-Host "Adding replication partnership $($localClusterInfo.name) <- $($remoteClusterInfo.name)"
$remotePartner = api post remoteClusters $remoteToLocal

setContext $localCluster
Write-Host "Adding replication partnership $($localClusterInfo.name) -> $($remoteClusterInfo.name)"
$localPartner = api post remoteClusters $localToRemote
