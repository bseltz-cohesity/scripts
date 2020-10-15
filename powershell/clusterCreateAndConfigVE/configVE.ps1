### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,          # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$pwd,          # new admin password
    [Parameter(Mandatory = $True)][string]$adminEmail,   # admin email address
    [Parameter(Mandatory = $True)][string]$adDomain,     # AD domain to join
    [Parameter(Mandatory = $True)][array]$preferredDC,  # preferred domain controller
    [Parameter(Mandatory = $True)][string]$adAdmin,      # AD admin account name
    [Parameter(Mandatory = $True)][string]$adPwd,        # AD admin password
    [Parameter()][string]$adOu = 'Computers',             # canonical name of container/OU
    [Parameter(Mandatory = $True)][string]$adAdminGroup, # AD admin group to add
    [Parameter(Mandatory = $True)][string]$timezone,     # timezone
    [Parameter(Mandatory = $True)][string]$smtpServer,   # smtp server address
    [Parameter(Mandatory = $True)][string]$supportPwd,   # support account new ssh password
    [Parameter(Mandatory = $True)][string]$alertEmail    # email address for critical alerts
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username admin -domain local -password admin

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
$null = api put users/linuxSupportUserSudoAccess @{"sudoAccessEnable" = $false}

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

