### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$netapp,    # the netapp to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username for netapp authentication
    [Parameter()][string]$password = $null  # password for netapp authentication (will be prompted if omitted)
)

function netappAPI($method, $uri, $data=$null){
    $uri = $baseurl + $uri
    $result = $null
    try{
        if($data){
            $BODY = ConvertTo-Json $data -Depth 99
            if($PSVersionTable.PSEdition -eq 'Core'){
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $BODY -SkipCertificateCheck
            }else{
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $BODY
            }
        }else{
            if($PSVersionTable.PSEdition -eq 'Core'){
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -SkipCertificateCheck
            }else{
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers
            }
        }
    }catch{
        if($_.ToString().contains('"errors" :')){
            Write-Host (ConvertFrom-Json $_.ToString()).errors[0].message -foregroundcolor Yellow
        }else{
            Write-Host $_.ToString() -foregroundcolor yellow
        }
    }
    return $result
}

# demand modern powershell version (must support TLSv1.2)
if($Host.Version.Major -le 5 -and $Host.Version.Minor -lt 1){
    Write-Warning "PowerShell version must be upgraded to 5.1 or higher to connect to Cohesity!"
    Pause
    exit
}

if($PSVersionTable.PSEdition -eq 'Desktop'){
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
    $ignoreCerts = @"
public class SSLHandler
{
    public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
    {
        return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
    }
}
"@

    if(!("SSLHandler" -as [type])){
        Add-Type -TypeDefinition $ignoreCerts
    }
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
}

$baseurl = 'https://' + $netapp + '/api/'

# authentication
if(!$password){
    $secureString = Read-Host -Prompt "Enter netapp password" -AsSecureString
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}
$EncodedAuthorization = [System.Text.Encoding]::UTF8.GetBytes($username + ':' + $password)
$EncodedPassword = [System.Convert]::ToBase64String($EncodedAuthorization)
$headers = @{"Authorization" = "Basic $($EncodedPassword)";
             "content-type" = "application/json";
             "accept" = "application/json"}

$interfaces = netappAPI get "network/ip/interfaces?fields=state%2Cuuid%2Cenabled%2Cname%2Csvm%2Cservices%2Cservice_policy%2Cvip%2Cscope%2Cipspace.name%2Cip.address%2Clocation.is_home%2Clocation.node.name%2Clocation.port.name%2Clocation.home_node.name%2Clocation.home_port.name%2Clocation.home_port.uuid%2Clocation.home_port.node"

$serviceText = @{
    'management_https' = 'HTTPS';
    'data_nfs' = '  NFS';
    'data_cifs' = '  SMB';
}
$servicePorts = @{
    'management_https' = @(443);
    'data_nfs' = @(111, 635, 2049, 4045, 4046);
    'data_cifs' = @(445);
}

function portTest($service, $ipAddress){
    if($serviceText.ContainsKey($service)){
        foreach($port in $servicePorts[$service]){
            if($PSVersionTable.PSEdition -eq 'Desktop'){
                $test = Test-NetConnection -ComputerName $ipAddress -Port $port -InformationLevel Quiet
            }else{
                $test = Test-Connection -TargetName $ipAddress -TcpPort $port
            }
            if($test){
                Write-Host "  $($serviceText[$service]) ($port):`tOK" -foregroundcolor Green
            }else{
                Write-Host "  $($serviceText[$service]) ($port):`tNo Response" -foregroundcolor Yellow
            }
        }
    }
}

Write-Host "`nPerforming Port Test..."

foreach($interface in $interfaces.records | Sort-Object -Property name){
    $ipAddress = $interface.ip.address
    $portScope = 'cluster'
    if($interface.scope -eq 'svm'){
        $portScope = $interface.svm.name
    }
    Write-Host ("`n{0}: {1} ($portScope)" -f $interface.name, $ipAddress)
    foreach($service in $interface.services){
        portTest $service $ipAddress
    }
}

Write-Host "`nPort Test Completed`n"
