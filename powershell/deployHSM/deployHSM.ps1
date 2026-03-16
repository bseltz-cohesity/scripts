
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$viServer, # vCenter to connect to
    [Parameter()][array]$viHost, # vSphere hosts to deploy OVA to
    [Parameter()][array]$viDataStore, # vSphere datastores to deploy OVA to
    [Parameter()][array]$vmName, # VM names
    [Parameter()][string]$ovfPath, # path to ova file
    [Parameter(Mandatory = $True)][array]$ip, # ip addresses of the nodes
    [Parameter(Mandatory = $True)][string]$netmask, # subnet mask
    [Parameter(Mandatory = $True)][string]$gateway, # default gateway
    [Parameter()][string]$network1, # VM port group name
    [Parameter()][string]$network2, # VM port group name
    [Parameter()][switch]$deployOVA,
    [Parameter()][int]$metadataSize = 512, # size of metadata disk
    [Parameter()][int]$dataSize = 1536, # size of data disk
    [Parameter()][switch]$buildCluster,
    [Parameter()][switch]$restore,
    [Parameter()][string]$vip, # VIP for cluster
    [Parameter()][array]$dnsServers, # dns servers
    [Parameter()][array]$ntpServers, # ntp servers
    [Parameter()][string]$clusterName, # Cohesity cluster name
    [Parameter()][string]$clusterDomain, # DNS domain of Cohesity cluster
    [Parameter()][string]$appSubnet,
    [Parameter()][string]$appNetmask,
    [Parameter()][string]$accessKey,
    [Parameter()][string]$secretKey,
    [Parameter()][string]$s3Host,
    [Parameter()][string]$s3Bucket,
    [Parameter()][string]$restorePrefix
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# validate input parameters
if($ip.count -lt 4){
    Write-Host 'Please specify at least 4 IP addresses' -ForegroundColor Yellow
    exit 1
}

if($deployOVA){
    if(!$viServer -or !$viDataStore -or !$viHost -or !$vmName -or !$ovfPath -or !$network1 -or !$network2){
        Write-Host "-deployOVA requires the following parameters:" -ForegroundColor Yellow
        Write-Host "  -viServer`n  -viDataStore`n  -viHost`n  -vmName`n  -ovfPath`n  -network1`n  -network2`n  -ip`n  -netmask`n  -gateway"
        exit 1
    }
    if($vmName.count -ne $ip.count -or 
        $viHost.count -ne $ip.count -or 
        $viDataStore.count -ne $ip.count){
        Write-Host 'Please provide the same number of IPs, vmNames, viHosts and viDatastores' -ForegroundColor Yellow
        exit 1
    }
}

if($restore -and !$buildCluster){
    Write-Host "-restore also requires -buildCluster" -ForegroundColor Yellow
    exit 1
}

if($buildCluster){
    if(!$vip -or !$dnsServers -or !$ntpServers -or !$clusterName -or !$clusterDomain -or !$appSubnet -or !$appNetmask){
        Write-Host "-buildCluster requires the following parameters:" -ForegroundColor Yellow
        Write-Host "  -clusterName`n  -clusterDomain`n  -vip`n  -ip`n  -netmask`n  -gateway`n  -dnsServers`n  -ntpServers`n  -appSubnet`n  -appNetmask`n" -ForegroundColor Yellow
        exit 1
    }
    if($restore){
        if(!$accessKey -or !$secretKey -or !$s3Bucket -or !$s3Host -or !$restorePrefix){
            Write-Host "-restore requires the following parameters:" -ForegroundColor Yellow
            Write-Host "  -accessKey`n  -secretKey`n  -s3Host`n  -s3Bucket`n  -restorePrefix`n" -ForegroundColor Yellow
            exit 1
        }
    }
}

# deploy OVAs
if($deployOVA){
    # connect to vCenter
    Write-Host "Connecting to vCenter..."
    $null = Connect-VIServer -Server $viServer -Force -WarningAction SilentlyContinue
    $tasks = @()
    0..($ip.count-1) | foreach {

        $nodeIndex = $_

        # set OVA configuration
        $ovfConfig = Get-OvfConfiguration -Ovf $ovfPath
        $ovfConfig.Common.dataIp.Value = $ip[$nodeIndex]
        $ovfConfig.Common.dataNetmask.Value = $netmask
        $ovfConfig.Common.dataGateway.Value = $gateway
        $ovfConfig.IpAssignment.IpProtocol.Value = 'IPv4'
        $ovfConfig.NetworkMapping.DataNetwork.Value = $network1
        $ovfConfig.NetworkMapping.SecondaryNetwork.Value = $network2 

        # deploy OVA
        write-host "Deploying OVA (node $($nodeIndex + 1) of $($ip.count))..."

        $VMHost = Get-VMHost -Name $viHost[$nodeIndex]
        $datastore = Get-Datastore -Name $viDataStore[$nodeIndex]
        $diskformat = 'Thin'
        $task = Import-VApp -Source $ovfPath -OvfConfiguration $ovfConfig -Name $vmName[$nodeIndex] -VMHost $VMHost -Datastore $datastore -DiskStorageFormat $diskformat -Confirm:$false -Force -RunAsync
        $tasks = @($tasks + $task)
    }

    # wait for OVAs
    Write-Host "Waiting for OVA deployments..."
    $finished = $False
    while($finished -eq $False){
        $finished = $True
        foreach($task in $tasks){
            # Write-Host "$($task.id) $($task.state)"
            if($task.state -eq 1){
                $finished = $False
                Start-Sleep 10
            }
        }
    }
    
    # add disks
    0..($ip.count-1) | foreach {
        $nodeIndex = $_
        $VM = get-vm -Name $vmName[$nodeIndex]
        $null = $VM | New-HardDisk -CapacityGB $metadataSize -Confirm:$false -Controller "SCSI Controller 1" -Persistence IndependentPersistent -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        $null = $VM | New-HardDisk -CapacityGB $dataSize -Confirm:$false -Controller "SCSI Controller 2" -Persistence IndependentPersistent -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    }
    # power on
    0..($ip.count-1) | foreach {
        $nodeIndex = $_
        $VM = get-vm -Name $vmName[$nodeIndex]
        $null = Start-VM $VM -ErrorAction SilentlyContinue
    }
}

if($buildCluster){

    $clusterBringupParams = @{
        "clusterName" = $clusterName;
        "clusterGateway" = $gateway;
        "clusterSubnetCidrLen" = $netmask;
        "dnsServers" = @($dnsServers);
        "domainNames" = @($clusterDomain);
        "hostname" = "$($clusterName).$($clusterDomain)";
        "ipPreference" = 1;
        "ntpAuthenticationEnabled" = $false;
        "ntpServers" = @($ntpServers);
        "appsSubnet" = $appSubnet;
        "appsSubnetMask" = $appNetmask;
        "vips" = @(
            $vip
        );
        "nodes" = @();
        "enableSoftwareEncryption" = $false;
        "enableHardwareEncryption" = $false;
        "rotationalPolicy" = 90;
        "restoreConfig" = $null
    }

    # wait for startup
    Write-Host "Waiting for VMs to boot..."

    apidrop -quiet
    while(!$cohesity_api.authorized){
        apiauth -vip $ip[0] -username admin -password admin -noDomain -quiet
        if(!$cohesity_api.authorized){
            Start-Sleep -Seconds 15
        }
    }

    $nodeCount = 0
    while($nodeCount -lt $ip.count){
        $nodecount = 0
        $nodes = api get -v2 clusters/nodes/free -quiet
        foreach($freenode in $nodes.nodes){
            if($freenode.primaryIPv4Address -in $ip){
                $nodecount += 1
            }
        }
        if($nodecount -lt $ip.count){
            sleep 15
        }else{
            foreach($freenode in $nodes.nodes){
                if($freenode.primaryIPv4Address -in $ip){
                    $clusterBringupParams.nodes += @{
                        'id' = $freenode.id;
                        'ip' = $freenode.primaryIPv4Address;
                        'ipmiIp' = ''
                    }
                }
            }        
        }
    }
    # restore parameters
    if($restore){
        $clusterBringupParams.restoreConfig =  @{
            "s3Config" = @{
                "accessKey" = $accessKey;
                "secretKey" = $secretKey;
                "bucket" = $s3Bucket;
                "host" = $s3Host
            };
            "objectPath" = @{
                "defaultPath" = $restorePrefix
            }
        }
        Write-Host "Building cluster with restore from $($restorePrefix)..."
    }else{
        Write-Host "Building cluster..."
    }
    # build cluster
    $null = api post /nexus/cluster/bringup $clusterBringupParams
}

Write-Host "`nProcess Completed`n"
