### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter()][string]$saasConnectorPassword,
    [Parameter()][string]$esxiPassword,
    [Parameter(Mandatory=$True)][string]$csvFile,
    [Parameter()][switch]$connect,
    [Parameter()][switch]$protect
)

if(! (Test-Path -Path $csvFile)){
    Write-Host "$csvFile not found" -ForegroundColor Yellow
    exit
}

if($connect){
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
}

if($protect){
    if(! $esxiPassword){
        $secureESXiPassword = Read-Host -Prompt "Enter registration password for ESXi" -AsSecureString
        $esxiPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureESXiPassword ))
    }
}

$csv = Import-Csv -Path $csvFile

foreach($site in $csv){
    Write-Host "`n=============================`n         Site: $($site.siteName)"
    Write-Host "       Region: $($site.region)"
    Write-Host "      vCenter: $($site.vCenter)"
    Write-Host "       vmName: $($site.vmName)"
    Write-Host "       vmHost: $($site.vmHost)"
    Write-Host "  vmDatastore: $($site.vmDatastore)"
    Write-Host "    vmNetwork: $($site.vmNetwork)"
    Write-Host "   IP Address: $($site.ip)"
    Write-Host "      Netmask: $($site.netmask)"
    Write-Host "      Gateway: $($site.gateway)"
    Write-Host " Domain Names: $($site.domainNames)"
    Write-Host "  DNS Servers: $($site.dnsServers)"
    Write-Host "  NTP Servers: $($site.ntpServers)"
    Write-Host "ESXi Hostname: $($site.esxiHostname)"
    Write-Host "    ESXi User: $($site.esxiUser)"
    Write-Host "       Policy: $($site.policyName)"
  
    if($connect){
        ./deploySaaSConnector.ps1 -username $username `
                                  -password $password `
                                  -deployOVA `
                                  -region $site.region `
                                  -vCenter $site.vCenter `
                                  -vmName $site.vmName `
                                  -vmHost $site.vmHost `
                                  -vmDatastore $site.vmDatastore `
                                  -vmNetwork $site.vmNetwork `
                                  -ip $site.ip `
                                  -netmask $site.netMask `
                                  -gateway $site.gateway `
                                  -diskFormat Thin `
                                  -saasConnectorPassword $saasConnectorPassword `
                                  -registerSaaSConnector `
                                  -connectionName $site.siteName `
                                  -domainNames @($site.domainNames -split ' ') `
                                  -dnsServers @($site.dnsServers -split ' ') `
                                  -ntpServers @($site.ntpServers -split ' ')
    }

    if($protect){
        $sourceName = ./registerESXiHostCCS.ps1 -username $username `
                                                -password $password `
                                                -connectionName $site.siteName `
                                                -esxiHostname $site.esxiHostname `
                                                -esxiUser $site.esxiUser `
                                                -esxiPassword $esxiPassword

        ./protectCcsVMs.ps1 -username $username `
                            -password $password `
                            -region $site.region `
                            -sourceName $sourceName `
                            -policyName $site.policyName `
                            -autoProtectSource
    }
}
