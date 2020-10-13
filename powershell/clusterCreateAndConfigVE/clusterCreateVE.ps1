
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$ip, # ip address of the node
    [Parameter(Mandatory = $True)][string]$netmask, # subnet mask
    [Parameter(Mandatory = $True)][string]$gateway, # default gateway
    [Parameter(Mandatory = $True)][String[]]$dnsServers, # dns servers
    [Parameter(Mandatory = $True)][String[]]$ntpServers, # ntp servers
    [Parameter(Mandatory = $True)][string]$clusterName, # Cohesity cluster name
    [Parameter(Mandatory = $True)][string]$clusterDomain # DNS domain of Cohesity cluster
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$REPORTAPIERRORS = $false

apidrop -quiet
while($AUTHORIZED -eq $false){
    apiauth -vip $ip -username admin -domain local -password admin -quiet
    if($AUTHORIZED -eq $false){
        Start-Sleep -Seconds 10
    }
}
apidrop -quiet

# perform cluster setup
write-host "Performing cluster setup..."

$cluster = $null
$clusterId = $null
while($cluster.length -eq 0){
    apiauth -vip $ip -username admin -domain local -password admin -quiet
    if($AUTHORIZED -eq $true){
        $myObject = @{
            "clusterName" = $clusterName;
            "ntpServers" = $ntpServers;
            "dnsServers" = $dnsServers;
            "domainNames" = @(
                $clusterDomain
            );
            "clusterGateway" = $gateway;
            "clusterSubnetCidrLen" = $netmask;
            "ipmiGateway" = $null;
            "ipmiSubnetCidrLen" = $null;
            "ipmiUsername" = $null;
            "ipmiPassword" = $null;
            "enableEncryption" = $True;
            "rotationalPolicy" = 90;
            "enableFipsMode" = $True;
            "nodes" = @(
                @{
                    "id" = (api get /nexus/node/info).nodeId;
                    "ip" = "$ip";
                    "ipmiIp" = ""
                }
            );
            "clusterDomain" = $clusterDomain;
            "nodeIp" = "$ip";
            "hostname" = $clusterName
        }
        $cluster = api post /nexus/cluster/virtual_robo_create $myObject
        $clusterId = $cluster.clusterId
    }else{
        Start-Sleep -Seconds 10
    }
}
write-host "New clusterId is $clusterId"
apidrop -quiet

# wait for startup
write-host "Waiting for cluster setup to complete..."

$clusterId = $null
while($null -eq $clusterId){
    Start-Sleep -Seconds 10
    apiauth -vip $ip -username admin -domain local -password admin -quiet
    $clusterId = (api get cluster).id
}
apidrop -quiet

$synced = $false
while($synced -eq $false){
    Start-Sleep -Seconds 10
    apiauth -vip $ip -username admin -domain local -password admin -quiet
    if($AUTHORIZED -eq $true){
        $stat = api get /nexus/cluster/status
        if($stat.isServiceStateSynced -eq $true){
            $synced = $true
        }
    }    
}

write-host "Cluster setup complete"
