# usage: ./registerVcenter.ps1 -vip mycluster -username myuser -domain mydomain.net -vcenter vcenter.mydomain.net -vcuser administrator@vsphere.local

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$vcenter,  # DNS or IP of vCenter
    [Parameter(Mandatory = $True)][string]$vcuser  # vCenter username
)

# source the cohesity-api helper code
. ./cohesity-api

# authenticate
apiauth -vip $vip -username $username -domain $domain

$secureString = Read-Host -Prompt "Enter Password for vCenter user $vcuser" -AsSecureString
$pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))

$registerVcenter = @{
    "entity"                 = @{
        "type"         = 1;
        "vmwareEntity" = @{
            "type" = 0
        }
    };
    "entityInfo"             = @{
        "endpoint"    = $vcenter;
        "type"        = 1;
        "credentials" = @{
            "username" = $vcuser;
            "password" = $pw
        }
    };
    "registeredEntityParams" = @{
        "isSpaceThresholdEnabled" = $false;
        "spaceUsagePolicy"        = @{ };
        "throttlingPolicy"        = @{
            "isThrottlingEnabled"             = $false;
            "isDatastoreStreamsConfigEnabled" = $false;
            "datastoreStreamsConfig"          = @{ }
        }
    }
}
Clear-Variable pw
write-host "Registering $vcenter..." 
$null = api post /backupsources $registerVcenter
