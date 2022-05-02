### usage: ./recoverNas.ps1 -vip mycluster -username admin -shareName \\netapp1.mydomain.net\share1 -viewName share1

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$shareName, #sharename as listed in sources
    [Parameter(Mandatory = $True)][string]$viewName, #name of the view to create
    [Parameter()][array]$fullControl,                 # list of users to grant full control
    [Parameter()][array]$readWrite,                   # list of users to grant read/write
    [Parameter()][array]$readOnly,                    # list of users to grant read-only
    [Parameter()][array]$modify,                      # list of users to grant modify
    [Parameter()][string]$sourceName = $null
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### hard coding the qos selection
$qosSetting = 'TestAndDev High'

### get AD info
$ads = api get activeDirectory
$sids = @{}

### find the VM to recover
$shares = api get restore/objects?search=$shareName

### narrow results to VMs with the exact name
$exactShares = $shares.objectSnapshotInfo | Where-Object {$_.snapshottedSource.name -ieq $shareName} #).objectSnapshotInfo[0]

if($sourceName){
    $exactShares = $exactShares | Where-Object {$_.registeredSource.name -ieq $sourceName }
}

if(! $exactShares){
    write-host "No matches found!" -ForegroundColor Yellow
    exit
}
### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestsnapshot = ($exactShares | sort-object -property @{Expression={$_.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

$nasRecovery = @{
    "name" = "Recover-$shareName";
    "objects" = @(
        @{
            "jobId" = $latestsnapshot.jobId;
            "jobUid" = $latestsnapshot.jobUid;
            "jobRunId" = $latestsnapshot.versions[0].jobRunId;
            "startedTimeUsecs" = $latestsnapshot.versions[0].startedTimeUsecs;
            "protectionSourceId" = $latestsnapshot.snapshottedSource.id
        }
    );
    "type" = "kMountFileVolume";
    "viewName" = $viewName;
    "restoreViewParameters" = @{
        "qos" = @{
            "principalName" = $qosSetting
        }
    }
}

# apply share permissions
$sharePermissionsApplied = $False
$sharePermissions = @()


function addPermission($user, $perms){
    if($user.contains('\')){
        $workgroup, $user = $username.split('\')
        # find domain
        $adDomain = $ads | Where-Object { $_.workgroup -eq $workgroup -or $_.domainName -eq $workgroup}
        if(!$adDomain){
            write-host "domain $workgroup not found!" -ForegroundColor Yellow
            exit 1
        }else{
            # find domain princlipal/sid
            $domainName = $adDomain.domainName
            $principal = api get "activeDirectory/principals?domain=$($domainName)&includeComputers=true&search=$($user)"
            if(!$principal){
                write-host "user $($user) not found!" -ForegroundColor Yellow
            }else{
                $sid = $principal[0].sid
                $sids[$user] = $sid
            }
        }
    }else{
        # find local or wellknown sid
        $principal = api get "activeDirectory/principals?includeComputers=true&search=$($user)"
        if(!$principal){
            write-host "user $($user) not found!" -ForegroundColor Yellow
        }else{
            $sid = $principal[0].sid
            $sids[$user] = $sid
        }
    }

    if($sid){
        $permission = @{
            "visible" = $True;
            "sid" = $sid;
            "type" = "Allow";
            "access" = $perms
        }
        return $permission
    }else{
        Write-Warning "User $user not found"
        exit 1
    }
}


foreach($user in $readWrite){
    $sharePermissionsApplied = $True
    $sharePermissions += addPermission $user 'ReadWrite'
    
}

foreach($user in $fullControl){
    $sharePermissionsApplied = $True
    $sharePermissions += addPermission $user 'FullControl'
}

foreach($user in $readOnly){
    $sharePermissionsApplied = $True
    $sharePermissions += addPermission $user 'ReadOnly'
}

foreach($user in $modify){
    $sharePermissionsApplied = $True
    $sharePermissions += addPermission $user 'Modify'
}

if($sharePermissionsApplied -eq $False){
    $sharePermissions += addPermission "Everyone" 'FullControl'
}

"Recovering $shareName as view $viewName"

$result = api post restore/recover $nasRecovery
if($result){
    sleep 1
    $newView = (api get -v2 file-services/views).views | Where-Object { $_.name -eq $viewName }
    $newView | setApiProperty -name Category -value 'FileServices'
    $newView | setApiProperty -name enableSmbViewDiscovery -value $True
    $newView | setApiProperty -name sharePermissions -value @($sharePermissions)
    $newView.qos = @{
        "principalName" = 'TestAndDev High';
    }
    $null = api put -v2 file-services/views/$($newView.viewId) $newView
}
