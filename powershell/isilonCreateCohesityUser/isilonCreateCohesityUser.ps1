### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$isilon,   # the isilon to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username 
    [Parameter()][string]$password = $null,  # optional, will be prompted if omitted
    [Parameter()][string]$cohesityUsername = 'cohesity',
    [Parameter()][string]$cohesityPassword = $null
)

function isilonAPI($method, $uri, $data=$null){
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

$baseurl = 'https://' + $isilon +":8080"

# authentication
if(!$password){
    $secureString = Read-Host -Prompt "Enter your Isilon password" -AsSecureString
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}
$EncodedAuthorization = [System.Text.Encoding]::UTF8.GetBytes($username + ':' + $password)
$EncodedPassword = [System.Convert]::ToBase64String($EncodedAuthorization)
$headers = @{"Authorization"="Basic $($EncodedPassword)"}

"`nCreating user $cohesityUsername..."
if(!$cohesityPassword){
    while($True){
        $secureString = Read-Host -Prompt "Enter new password for $cohesityUsername" -AsSecureString
        $cohesityPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
        $secureString = Read-Host -Prompt "  Confirm password for $cohesityUsername" -AsSecureString
        $cohesityPassword2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
        if($cohesityPassword -eq $cohesityPassword2){
            break
        }else{
            Write-Host "passwords do not match`n" -foregroundcolor Yellow
        }
    }
}

$userParams = @{
    "name" = $cohesityUsername;
    "enabled" = $True;
    "shell" = "/bin/zsh";
    "password_expires" = $false;
    "password" = $cohesityPassword
}

$newUser = isilonAPI post /platform/1/auth/users $userParams

$roleParams = @{
    "name" = $cohesityUsername;
    "members" = @(
        @{
            "name" = $cohesityUsername;
            "type" = "user"
        }
    );
    "privileges" = @(
        @{
            "id" = "ISI_PRIV_LOGIN_PAPI";
            "name" = "Platform API";
            "read_only" = $True
        };
        @{
            "id" = "ISI_PRIV_AUTH";
            "name" = "Auth";
            "read_only" = $True
        };
        @{
            "id" = "ISI_PRIV_CLUSTER";
            "name" = "Cluster";
            "read_only" = $True
        };
        @{
            "id" = "ISI_PRIV_JOB_ENGINE";
            "name" = "Job Engine";
            "read_only" = $false
        };
        @{
            "id" = "ISI_PRIV_NETWORK";
            "name" = "Network";
            "read_only" = $True
        };
        @{
            "id" = "ISI_PRIV_SMB";
            "name" = "SMB";
            "read_only" = $True
        };
        @{
            "id" = "ISI_PRIV_SNAPSHOT";
            "name" = "Snapshot";
            "read_only" = $false
        };
        @{
            "id" = "ISI_PRIV_NFS";
            "name" = "NFS";
            "read_only" = $false
        }
    )
}

"`nCreating role for $cohesityUsername..."
$newRole = isilonAPI post /platform/1/auth/roles $roleParams
"`nUser/Role creation completed"
