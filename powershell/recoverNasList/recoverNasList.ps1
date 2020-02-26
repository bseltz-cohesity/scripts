# usage: ./recoverNasList.ps1 -vip mycluster -username admin -nasList .\nasList.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$fullControl,                 # list of users to grant full control
    [Parameter()][array]$readWrite,                   # list of users to grant read/write
    [Parameter()][array]$readOnly,                    # list of users to grant read-only
    [Parameter()][array]$modify,                      # list of users to grant modify
    [Parameter()][string]$nasList = './naslist.txt'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

### get AD info
$ads = api get activeDirectory
$sids = @{}


function addPermission($username, $perms){
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
                write-host "user $($username) not found!" -ForegroundColor Yellow
            }else{
                $sid = $principal[0].sid
                $sids[$username] = $sid
            }
        }
    }else{
        # find local or wellknown sid
        $principal = api get "activeDirectory/principals?includeComputers=true&search=$($username)"
        if(!$principal){
            write-host "user $($username) not found!" -ForegroundColor Yellow
        }else{
            $sid = $principal[0].sid
            $sids[$username] = $sid
        }
    }

    if($sid){
        $permission = @{
            "visible" = $True;
            "sid" = $sid;
            "type" = "kAllow";
            "access" = $perms
        }
        return $permission
    }else{
        Write-Warning "User $user not found"
        exit 1
    }
}


# get input file
$nasListFile = Get-Content $nasList

foreach($shareName in $nasListFile){

    # find nas share to recover
    $shares = api get restore/objects?search=$shareName
    $exactShares = $shares.objectSnapshotInfo | Where-Object {$_.snapshottedSource.name -ieq $shareName}

    if(! $exactShares){
        write-host "Can't find $shareName - skipping..." -ForegroundColor Yellow
    }else{

        $newViewName = $shareName.split('\')[-1].split('/')[-1]

        # select latest snapshot to recover
        $latestsnapshot = ($exactShares | sort-object -property @{Expression={$_.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

        # new view parameters
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
            "viewName" = $newViewName;
            "restoreViewParameters" = @{
                "qos" = @{
                    "principalName" = "TestAndDev High"
                }
            }
        }

        "Recovering $shareName as view $newViewName"

        # perform the recovery
        $result = api post restore/recover $nasRecovery

        if($result){

            # set post recovery view settings

            # apply share permissions
            $sharePermissionsApplied = $False
            $sharePermissions = @()

            foreach($user in $readWrite){
                $sharePermissionsApplied = $True
                $sharePermissions += addPermission $user 'kReadWrite'
                
            }
            
            foreach($user in $fullControl){
                $sharePermissionsApplied = $True
                $sharePermissions += addPermission $user 'kFullControl'
            }
            
            foreach($user in $readOnly){
                $sharePermissionsApplied = $True
                $sharePermissions += addPermission $user 'kReadOnly'
            }
            
            foreach($user in $modify){
                $sharePermissionsApplied = $True
                $sharePermissions += addPermission $user 'kModify'
            }
            
            if($sharePermissionsApplied -eq $False){
                $sharePermissions += addPermission "Everyone" 'kFullControl'
            }

            do {
                $newView = (api get views).views | Where-Object { $_.name -eq $newViewName }
                sleep 1
            } until ($newView)
            
            $newView | setApiProperty -name enableSmbViewDiscovery -value $True
            $newView | setApiProperty -name enableSmbAccessBasedEnumeration -value $True
            $newView | setApiProperty -name protocolAccess -value 'kSMBOnly'
            $newView | setApiProperty -name sharePermissions -value $sharePermissions
            $newView.qos = @{
                "principalName" = 'TestAndDev High';
            }
            $null = api put views $newView
        }
    }
}
