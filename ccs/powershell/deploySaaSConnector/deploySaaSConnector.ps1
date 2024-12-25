
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][string]$ip, # ip address of the node
    [Parameter()][string]$netmask, # subnet mask
    [Parameter()][string]$gateway, # default gateway
    [Parameter()][string]$ip2, # ip address of the node
    [Parameter()][string]$netmask2, # subnet mask
    [Parameter()][string]$gateway2, # default gateway
    [Parameter()][string]$vmNetwork, # VM port group name
    [Parameter()][string]$vmNetwork2, # VM port group name
    [Parameter()][string]$vmName, # VM name
    [Parameter()][array]$dnsServers, # dns servers
    [Parameter()][array]$ntpServers, # ntp servers
    [Parameter()][array]$domainNames,
    [Parameter()][string]$vCenter, # vCenter to connect to
    [Parameter()][string]$vmHost, # vSphere host to deploy OVA to
    [Parameter()][string]$vmDatastore, # vSphere datastore to deploy OVA to
    [Parameter()][ValidateSet('Thin','Thick')][string]$diskFormat = 'Thick',
    [Parameter()][string]$ovfPath, # path to ova file
    [Parameter()][switch]$deployOVA,
    [Parameter()][switch]$downloadOVA,
    [Parameter()][string]$downloadPath = '.',
    [Parameter()][string]$saasConnectorPassword,
    [Parameter()][switch]$registerSaaSConnector,
    [Parameter()][switch]$unregisterSaaSConnector,
    [Parameter()][string]$connectionName,
    [Parameter()][switch]$returnIp,
    [Parameter()][string]$folderName,
    [Parameter()][string]$parentFolderName,
    [Parameter()][switch]$wait
)

. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if(! $ovfPath){
    $ovfPath = 'saasConnector.ova'
    if($downloadPath -ne '.'){
        $ovfPath = Join-Path -Path $downloadPath -ChildPath saasConnector.ova
    }
}

# validate parameters
if($registerSaaSConnector){
    if($domainNames.Count -eq 0){
        Write-Host "-domainNames is required" -ForegroundColor Yellow
        exit
    }
    if(! $connectionName){
        Write-Host "-connectionName is required" -ForegroundColor Yellow
        exit
    }
}

if($deployOVA -or ($registerSaaSConnector -and ! $ip) -or ($unregisterSaaSConnector -and ! $ip)){
    if(! $vCenter){
        Write-Host "-viServer is required" -ForegroundColor Yellow
        exit
    }
    if(! $vmName){
        Write-Host "-vmName is required" -ForegroundColor Yellow
        exit
    }
    if($deployOVA){
        if(! $vmDatastore -or ! $vmHost -or ! $vmNetwork){
            Write-Host "-vmHost, -viDatastore and -vmNetwork are required" -ForegroundColor Yellow
            exit
        }
    }
}

function getVMIp($vmName){
    $vmIp = $null
    while($null -eq $vmIp){
        $vm = Get-VM -Name $vmName
        $vmIp = $vm.Guest.IPAddress[0]
        if($null -eq $vmIp){
            Start-Sleep -Seconds 10
        }
    }
    return $vmIp
}

# authenticate to CCS
if($downloadOVA -or $registerSaaSConnector -or $unregisterSaaSConnector){
    # authenticate to CCS
    Write-Host "Connecting to Cohesity Cloud..."
    apiauth -username $username -passwd $password
    # exit on failed authentication
    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated" -ForegroundColor Yellow
        exit 1
    }
    $userInfo = api get /mcm/userInfo
    $tenantId = $userInfo.user.profiles[0].tenantId
    $ccsContext = getContext
}

# download OVA
if($downloadOVA){
    # get OVA download path
    $images = api get -mcmv2 rigelmgmt/regions/$($region.ToLower())/images
    $downloadURL = $images.downloadLink
    Write-Host "Downloading OVA..."
    # fileDownload -uri $downloadURL -fileName saasConnector.ova
    Start-BitsTransfer -Source $downloadURL -Destination $ovfPath -Description "Downloading SaaS Connector OVA to $($ovfPath)..."
    if(Test-Path -Path $ovfPath){
        Write-Host "OVA $ovfPath Downloaded"
    }else{
        Write-Host "File $ovfPath not found" -ForegroundColor Yellow
    }
}

# connect to vCenter
if($deployOVA -or ($registerSaaSConnector -and ! $ip) -or ($unregisterSaaSConnector -and ! $ip)){
    Write-Host "Connecting to vCenter..."
    $null = Connect-VIServer -Server $vCenter -Force -WarningAction SilentlyContinue
}

# deploy OVA
if($deployOVA){
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if($vm){
        Write-Host "VM $vmName already exists" -ForegroundColor Yellow
        exit
    }
    if($folderName){
        $folder = Get-Folder -Name $folderName -ErrorAction SilentlyContinue
        if($parentFolderName){
            $folder = $folder | Where-Object {$_.Parent.Name -eq $parentFolderName}
        }
        if(! $folder){
            Write-Host "VM Folder $folderName not found" -ForegroundColor Yellow
            exit
        }
        $folder = $folder[0]
    }
    if(! (Test-Path -Path $ovfPath)){
        Write-Host "OVF file $ovfPath not found" -ForegroundColor Yellow
        exit
    }
    # prompt for new SaaS Connector Password
    if(! $saasConnectorPassword){
        $saasConnectorPassword = '1'
        $confirmPassword = '2'
        while($saasConnectorPassword -cne $confirmPassword){
            $secureNewPassword = Read-Host -Prompt "  Enter new admin password for SaaS Connector" -AsSecureString
            $secureConfirmPassword = Read-Host -Prompt "Confirm new admin password for SaaS Connector" -AsSecureString
            $saasConnectorPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureNewPassword ))
            $confirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureConfirmPassword ))
            if($saasConnectorPassword -cne $confirmPassword){
                Write-Host "Passwords do not match" -ForegroundColor Yellow
            }
        }
    }
    # set OVA configuration
    Write-Host "Setting OVA configuration..."

    $ovfConfig = Get-OvfConfiguration -Ovf $ovfPath

    # select deployment option
    $ovfConfig.DeploymentOption.Value = 'saas-connector'

    # select region
    $ovfConfig.Common.region.Value = $region

    # select VM networks
    $ovfConfig.NetworkMapping.DataNetwork.Value = $vmNetwork
    $ovfConfig.NetworkMapping.SecondaryNetwork.Value = $vmNetwork
    if($vmNetwork2){
        $ovfConfig.NetworkMapping.SecondaryNetwork.Value = $vmNetwork2
    }

    # specify IP settings
    $ipAllocationPolicy = 'dhcpPolicy'

    if($ip){
        $ipAllocationPolicy = 'fixedPolicy'
        if(! $netmask -or ! $gateway){
            Write-Host "-netmask and -gateway required for static IP addressing" -ForegroundColor Yellow
            exit
        }
        $ovfConfig.Common.dataIp.Value = $ip
        $ovfConfig.Common.dataNetmask.Value = $netmask
        $ovfConfig.Common.dataGateway.Value = $gateway
        if($vmNetwork2){
            if(! $ip2 -or ! $netmask2 -or ! $gateway2){
                Write-Host "-ip2 and -netmask2 and -gateway2 required for static IP addressing" -ForegroundColor Yellow
                exit
            }
            $ovfConfig.Common.secondaryIp.Value = $ip2
            $ovfConfig.Common.secondaryNetmask.Value = $netmask2
            $ovfConfig.Common.secondaryGateway.Value = $gateway2
        }
    }
    $ovfConfig.IpAssignment.IpAllocationPolicy.Value = $ipAllocationPolicy
    $ovfConfig.IpAssignment.IpProtocol.Value = 'IPv4'

    # deploy OVA
    Write-Host "Deploying OVA..."

    $vHost = Get-VMHost -Name $vmHost
    if(! $vHost){
        Write-Host "VM Host $vmHost not found" -ForegroundColor Yellow
        exit
    }
    $datastore = Get-Datastore -Name $vmDatastore
    if(! $datastore){
        Write-Host "Datastore $vmDatastore not found" -ForegroundColor Yellow
        exit
    }
    if($folderName){
        $null = Import-VApp -Source $ovfPath -OvfConfiguration $ovfConfig -Name $vmName -VMHost $vHost -Datastore $datastore -DiskStorageFormat $diskFormat -InventoryLocation $folder -Confirm:$false -Force
    }else{
        $null = Import-VApp -Source $ovfPath -OvfConfiguration $ovfConfig -Name $vmName -VMHost $vHost -Datastore $datastore -DiskStorageFormat $diskFormat -Confirm:$false -Force
    }
    

    $vm = Get-VM -Name $vmName
    if(! $vm){
        Write-Host "VM not found" -ForegroundColor Yellow
        exit
    }

    # power on VM
    Write-Host "Powering on VM..."
    $null = Start-VM $vm

    # get VM IP Address
    $vmIp = getVMIp $vmName

    # authenticate to SaaS Connector and update the password
    $saasConnectorPassword = Set-CohesityAPIPassword -vip $vmIp -username admin -passwd $saasConnectorPassword -quiet
    $cohesity_api.reportApiErrors = $false
    $clusterId = $null
    apidrop -quiet
    while($null -eq $clusterId){
        Start-Sleep -Seconds 10
        apiauth $vmIp admin -passwd admin -newPassword $saasConnectorPassword -quiet -noPrompt
        $clusterId = (api get cluster -quiet).id
    }
    apidrop -quiet
    $cohesity_api.reportApiErrors = $True
    
    if($null -ne $clusterId){
        Write-Host "SaaS Connector $vmName ($vmIp) is Online"
        return $vmIp
    }
}

# unregister SaaS Connector
if($unregisterSaaSConnector){
    # get SaaS Connector IP Address
    if($ip){
        $vmIp = $ip
    }else{
        $vmIp = getVMIp $vmName
    }

    # authenticate to ccs
    apidrop -quiet
    setContext $ccsContext

    # find existing rigel group
    $rigelGroups = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&fetchConnectorGroups=true"
    $existingRigelGroup = $rigelGroups.rigelGroups | Where-Object {$vmIp -in $_.connectorGroups.connectors.rigelIp}
    if(! $existingRigelGroup){
        Write-Host "SaaS Connector $vmIp is not registered"
        exit
    }else{
        $connector = $existingRigelGroup.connectorGroups.connectors | Where-Object {$_.rigelIp -eq $vmIp}
        $rigelGuid = $connector.rigelGuid
        Write-Host "Unregistereing SaaS Connector $vmIp..."
        $response = api delete -mcmv2 "rigelmgmt/rigels?tenantId=$tenantId&rigelGuid=$($rigelGuid)"
    }
}

# register SaaS Connector in CCS
if($registerSaaSConnector){

    # get SaaS Connector IP Address
    if($ip){
        $vmIp = $ip
    }else{
        $vmIp = getVMIp $vmName
    }

    # authenticate to ccs
    apidrop -quiet
    setContext $ccsContext

    # check if already registered
    $rigelGroups = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&fetchConnectorGroups=true"
    $existingRigelGroup = $rigelGroups.rigelGroups | Where-Object {$vmIp -in $_.connectorGroups.connectors.rigelIp}
    if($existingRigelGroup){
        Write-Host "$vmIp is already registered to SaaS Connection $($existingRigelGroup.groupName)" -ForegroundColor Yellow
        exit
    }else{
        Write-Host "Requesting Claim Code..."
        $rigelGroup = $rigelGroups.rigelGroups | Where-Object {$_.groupName -eq $connectionName}
        if($rigelGroup){
            # get existing rigel group
            $groupId = $rigelGroup.groupId
            $rigelGroup = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&groupId=$groupId&fetchToken=true"
            $claimToken = $rigelGroup.rigelGroups[0].claimToken
        }else{
            # create new rigel group
            $rigelParams = @{
                "regionId" = $region.ToLower();
                "name" = $connectionName;
                "tenantId" = $tenantId
            }
            $rigelResponse = api post -mcmv2 rigelmgmt/rigel-groups $rigelParams
            $claimToken = $rigelResponse.claimToken
        }
        
        Write-Host "Claim Code is $claimToken"

        # connect to SaaS Connector
        Write-Host "Connecting to SaaS Connector..."
        apidrop -quiet
        apiauth $vmIp admin
        $cluster = api get -v2 clusters
        if($ntpServers.Count -gt 0){
            $cluster.networkConfig.ntpServers = @($ntpServers)
        }
        if($domainNames.Count -gt 0){
            $cluster.networkConfig.domainNames = @($domainNames)
        }
        if($cluster.networkConfig.useDhcp -eq $false){
            if($dnsServers.Count -gt 0){
                $cluster.networkConfig.manualNetworkConfig.dnsServers = @($dnsServers)
                if($cluster.networkConfig.PSObject.Properties['secondaryManualNetworkConfig']){
                    $cluster.networkConfig.secondaryManualNetworkConfig.dnsServers = @($dnsServers)
                }
            }
        }
        $node = api get nodes
        $cluster.rigelClusterParams = @{
            "claimToken" = $claimToken;
            "nodes" = @(
                @{
                    "nodeIp" = $vmIp;
                    "secondaryNodeIp" = "undefined";
                    "nodeId" = $node.id
                }
            )
        }
        Write-Host "Registering SaaS Connector..."
        $response = api put -v2 clusters $cluster
        $registration = api post -v2 helios-registration @{"registrationToken" = $claimToken}
        # wait for SaaS connector to connect
        Write-Host "Waiting for SaaS Connector to Connect..."
        apidrop -quiet
        setContext $ccsContext
        $connectorStatus = 'disconnected'
        while($connectorStatus -eq 'disconnected'){
            $rigelGroups = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&fetchConnectorGroups=true"
            $rigelGroup = $rigelGroups.rigelGroups | Where-Object {$vmIp -in $_.connectorGroups.connectors.rigelIp}
            $connector = $rigelGroup.connectorGroups.connectors | Where-Object {$_.rigelIp -eq $vmIp}
            if($connector.isConnectedToControlPlane -eq $True -and $connector.isConnectedToDataPlane -eq $True){
                $connectorStatus = 'connected'
                break
            }else{
                Start-Sleep 10
            }
        }
    }
}

Write-Host "SaaS Connector Deployment Complete"
