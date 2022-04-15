### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$netapp,    # the netapp to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username for netapp authentication
    [Parameter()][string]$password = $null,  # password for netapp authentication (will be prompted if omitted)
    [Parameter()][string]$cohesityUsername = 'cohesity',  # netapp api username to create
    [Parameter()][string]$cohesityPassword = $null,  # netapp api password for new user (will be prompted if omitted)
    [Parameter()][string]$vServer = $null,  # vserver name (if creating user on SVM)
    [Parameter()][switch]$createSMBUser,
    [Parameter()][switch]$delete
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
    Write-Host "PowerShell version must be upgraded to 5.1 or higher!" -foregroundcolor Yellow
    Pause
    exit
}

# demand Netapp PowerShell Toolkit
if(! (Get-Command -Name Connect-NcController*)){
    Write-Host "This script requires the Netapp PowerShell Toolkit!" -foregroundcolor Yellow
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

# get cluster info
$cluster = netappAPI get cluster
$clusterName = $cluster.name
if([int]$cluster.version.generation -lt 9 -or [int]$cluster.version.major -lt 6){
    Write-Host "This script requires NetApp release 9.6 or later" -foregroundcolor Yellow
    exit
}

$secureNetAppPassword = ConvertTo-SecureString $password -AsPlainText -Force
$netAppCreds = New-Object System.Management.Automation.PSCredential ($userName, $secureNetAppPassword)

$svmUuid = $null
if($vServer){
    $svm = (netappAPI get "svm/svms?name=$vServer").records | Where-Object name -eq $vServer
    if(!$svm){
        Write-Host "SVM $vServer not found!" -foregroundcolor Yellow
        exit
    }
    $svmUuid = $svm.uuid
}

# get list of vServers
$svms = netappAPI get svm/svms
if($vServer){
    if($vServer -notin $svms.records.name){
        Write-Host "vServer $vServer not found!" -ForegroundColor Yellow
        exit
    }
    $vServers = @($vServer)
}else{
    $vServers = @($svms.records.name)
}

# get existing users and roles
$existingRoles = netappAPI get "private/cli/security/login/role?vserver=$clusterName"
$existingRole = $existingRoles.records | Where-Object role -eq $cohesityUsername
$existingUsers = netappAPI get "security/accounts?fields=*&owner.name=$clusterName"
$existingUser = $existingUsers.records | Where-Object Name -eq $cohesityUsername

if($delete){
    if($existingUser){
        Write-Host "Deleting API user $cohesityUsername..."
        $deleteUser = netappAPI delete "security/accounts/$($existingUser.owner.uuid)/$cohesityUsername"
    }else{
        Write-Host "API user $cohesityUsername not found"
    }
    if($existingRole){
        Write-Host "Deleting API roles for $cohesityUsername..."
        $deleteRole = netappAPI delete "private/cli/security/login/role?role=$cohesityUsername&vserver=$clusterName"
    }
    foreach($vServer in $vServers){
        $netAppConnection = Connect-NcController -Name $netapp -HTTPS -Vserver $vServer -Credential $netAppCreds
        $existingUsers = Get-NcCifsLocalUser
        $existingUser = $existingUsers | Where-Object {$_.UserName -eq "$vServer\$cohesityUsername" -or $_.UserName -eq "$clusterName\$cohesityUsername"}
        if($existingUser){
            $myObject = @{
                "vserver" = $vServer;
                "user-or-group-name" = $cohesityUsername;
                "privileges" = @('SeBackupPrivilege', 'SeRestorePrivilege', 'SeChangeNotifyPrivilege')
            }
            $userPrivs = netappAPI post private/cli/vserver/cifs/users-and-groups/privilege/remove-privilege $myObject
            
            $myObject = @{
                "vserver" = $vServer;
                "group-name" = "BUILTIN\Backup Operators";
                "member-names" = @($cohesityUsername)
            }
            $userGroup = netappAPI post private/cli/vserver/cifs/users-and-groups/local-group/remove-members $myObject
            Write-Host "$($vServer): Deleting CIFS user $cohesityUsername..."
            $deleteUser = Remove-NcCifsLocalUser -UserName $cohesityUsername -Confirm:$false
            $deleteUser
        }
    }
    exit
}

# prompt for cohesity password
"`nCreating API user $cohesityUsername..."
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

$secureCohesityPassword = ConvertTo-SecureString $cohesityPassword -AsPlainText -Force

# create roles
$roleAccess = @{
    "vserver export-policy" = "all";
    "volume snapshot" = "all";
    "vserver cifs" = "readonly";
    "network interface" = "readonly";
    "volume" = "readonly";
    "vserver" = "readonly";
    "cluster identity" = "readonly";
    "sys stat" = "readonly";
    "system node run" = "readonly";
    "set" = "readonly";
    "diag" = "readonly"
}

if($vServer){
    $roleAccess = @{
        "vserver export-policy" = "all";
        "volume snapshot" = "all";
        "vserver cifs" = "readonly";
        "network interface" = "readonly";
        "volume" = "readonly";
        "vserver" = "readonly";
    }
}

foreach($role in $roleAccess.Keys){
    $myObject = @{
        "vserver" = $clusterName;
        "role" = $cohesityUsername;
        "cmddirname" = $role;
        "access" = $roleAccess[$role];
        "query" = ""
    }
    if($vServer){
        $myObject.vserver = $vServer
    }
    $existingRole = $existingRoles | Where-Object {$_.vserver -eq $clusterName -and $_.role -eq $cohesityUsername -and $_.cmddirname -eq $roleAccess[$role]}
    if(!$existingRole){
        $newRole = netappAPI post private/cli/security/login/role $myObject
    }
}

# create ontapi user
$myObject = @{
    "applications" =  @(
        @{
            "authentication_methods" = @(
                "password"
            );
            "application" = 'ontapi'
        }
    ); 
    "password" = $cohesityPassword;
    "name" = $cohesityUsername
}
if($svmUuid){
    $myObject['owner'] = @{
        "uuid" = $svmUuid
    }
}

$setUser = netappAPI post security/accounts $myObject

# create users for other services
$applications = @('http', 'ssh', 'console')
if($vServer){
    $applications = @('http', 'ssh')
}
foreach($application in $applications){
    $myObject = @{
        "username" = $cohesityUsername;
        "application" = $application;
        "authmethod" = "password";
        "role" = $cohesityUsername;
        "comment" = "cohesity_user"
    }
    if($vServer){
        $myObject['vserver'] = $vServer
    }
    $newUser = netappAPI post private/cli/security/login $myObject
}

if($createSMBUser){
    foreach($vServer in $vServers){
        "$($vServer): Creating CIFS user $cohesityUsername..."
        $netAppConnection = Connect-NcController -Name $netapp -HTTPS -Vserver $vServer -Credential $netAppCreds
        $newUser = New-NcCifsLocalUser -UserName $cohesityUsername -Password $secureCohesityPassword -FullName $cohesityUsername -VserverContext $vServer -Description 'cohesity_user'
    
        $myObject = @{
            "vserver" = $vServer;
            "user-or-group-name" = $cohesityUsername;
            "privileges" = @('SeBackupPrivilege', 'SeRestorePrivilege', 'SeChangeNotifyPrivilege')
        }
        $userPrivs = netappAPI post private/cli/vserver/cifs/users-and-groups/privilege/add-privilege $myObject
        
        $myObject = @{
            "vserver" = $vServer;
            "group-name" = "BUILTIN\Backup Operators";
            "member-names" = @($cohesityUsername)
        }
        
        $userGroup = netappAPI post private/cli/vserver/cifs/users-and-groups/local-group/add-members $myObject
    }
}

"`nUser creation completed`n"
