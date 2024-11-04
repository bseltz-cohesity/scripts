
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$ip,            # ip address of the node
    [Parameter(Mandatory = $True)][string]$netmask,       # subnet mask
    [Parameter(Mandatory = $True)][string]$gateway,       # default gateway
    [Parameter(Mandatory = $True)][String[]]$dnsServers,  # dns servers
    [Parameter(Mandatory = $True)][String[]]$ntpServers,  # ntp servers
    [Parameter(Mandatory = $True)][string]$clusterName,   # Cohesity cluster name
    [Parameter(Mandatory = $True)][string]$clusterDomain, # DNS domain of Cohesity cluster
    [Parameter(Mandatory = $True)][string]$pwd,           # new admin password
    [Parameter(Mandatory = $True)][string]$adminEmail,    # admin email address
    [Parameter(Mandatory = $True)][string]$adDomain,      # AD domain to join
    [Parameter(Mandatory = $True)][array]$preferredDC,   # preferred domain controller
    [Parameter()][string]$adOu = 'Computers',             # canonical name of container/OU
    [Parameter(Mandatory = $True)][string]$adAdmin,       # AD admin account name
    [Parameter(Mandatory = $True)][string]$adPwd,         # AD admin password
    [Parameter(Mandatory = $True)][string]$adAdminGroup,  # AD admin group to add
    [Parameter(Mandatory = $True)][string]$timezone,      # timezone
    [Parameter(Mandatory = $True)][string]$smtpServer,    # smtp server address
    [Parameter(Mandatory = $True)][string]$supportPwd,    # support account new ssh password
    [Parameter(Mandatory = $True)][string]$alertEmail     # email address for critical alerts
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

### authenticate
apiauth -vip $ip -username admin -domain local -password admin

# set admin password
"Setting admin password..."
$users = api get users | Where-Object username -eq 'admin'
setApiProperty -object $users[0] -name 'password' -value $pwd
setApiProperty -object $users[0] -name 'emailAddress' -value $adminEmail
$null = api put users $users[0]

# Accept EULA
"Accepting EULA..."
$signDate = (dateToUsecs (get-date))/1000000
$eulaParams = @{
    "signedVersion" = 3;
    "signedByUser" = "admin";
    "signedTime" = $signDate;
    "licenseKey" = "AYFN-1080-5VW2-GBOT"
}
$null = api post /licenseAgreement $eulaParams

# Skip Licensing
$null = api put cluster @{"licenseState" = @{"state" = "kSkipped"}}

# join active directory
"Joining Active Directory ($adDomain)..."
$cluster = api get cluster

$adParams = @{
    "domainName" = $adDomain;
    "preferredDomainControllers" = @();
    "machineAccounts" = @(
        @{
            "name" = $cluster.name
        }
    );
    "overwriteMachineAccounts" = $True;
    "activeDirectoryAdminParams" = @{
        "username" = $adAdmin;
        "password" = $adPwd
    };
    "organizationalUnitName" = $adOu;
    "trustedDomainParams" = @{
        "enabled" = $false
    }
}

foreach($dc in $preferredDC){
    $adParams.preferredDomainControllers += @{"name" = $dc}
}

$null = api post active-directories $adParams -v2

# set fqdn
"Setting FQDN..."
$vlan = api get vlans | Where-Object id -eq 0
$vlan.hostname = "{0}.{1}" -f $clusterName, $clusterDomain
delApiProperty -object $vlan.subnet -name netmaskBits
$null = api put vlans/0 $vlan

# timezone and documentation
"Setting timezone..."
$cluster.isDocumentationLocal = $True
$cluster.timezone = $timezone
$null = api put cluster $cluster

# smtp configuration
"Configuring SMTP..."
$smtpConfig = @{
    "disableSmtp" = $false;
    "port" = 25;
    "server" = $smtpServer
}

$null = api put /smtpServer $smtpConfig

# add AD admin group
"Granting admin permissions to $adAdminGroup..."
$adPrincipals = @(
    @{
        "principalName" = $adAdminGroup;
        "objectClass" = "kGroup";
        "roles" = @(
            "COHESITY_ADMIN"
        );
        "domain" = $adDomain;
        "restricted" = $false
    }
)

$null = api post activeDirectory/principals $adPrincipals

# support account
"Setting support password..."
$supportCreds = @{
    "linuxUsername" = "support";
    "linuxPassword" = $supportPwd;
    "linuxCurrentPassword" = $supportPwd
}

$null = api put users/linuxPassword $supportCreds
$null = api put users/linuxSupportUserSudoAccess @{"sudoAccessEnable" = $True}

# critical alerts
"Configuring critial alert recipients..."
$alertParams = @{
    "emailDeliveryTargets" = @(
        @{
            "emailAddress" = $alertEmail;
            "recipientType" = "kTo"
        }
    );
    "webHookDeliveryTargets" = @();
    "ruleName" = "Critical Alert Rule";
    "severities" = @(
        "kCritical"
    )
}

$null = api post alertNotificationRules $alertParams

# global whitelist
"Setting global whitelist..."
$globalWhiteList = @{
    "clientSubnets" = @(
        @{
            "ip" = "0.0.0.0";
            "netmaskIp4" = "0.0.0.0";
            "nfsAccess" = "kReadWrite";
            "smbAccess" = "kReadWrite";
            "description" = ""
        }
    )
}

$null = api put externalClientSubnets $globalWhiteList

# delete canned policies
"Removing canned policies..."
$REPORTAPIERRORS = $false
api get protectionPolicies | ForEach-Object {$null = api delete protectionPolicies/$($_.id)}

"Cluster configuration complete!"
