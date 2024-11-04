### usage: ./cloneView.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -viewName 'SMBShare' -newName 'Cloned-SMBShare'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][string]$viewName,
    [Parameter(Mandatory = $True)][string]$newName,
    [Parameter()][string]$vaultName = $null,
    [Parameter()][string]$backupDate = $null,
    [Parameter()][switch]$showVersions,
    [Parameter()][switch]$showDates,
    [Parameter()][switch]$deleteView,
    [Parameter()][array]$fullControl,
    [Parameter()][array]$readWrite,
    [Parameter()][array]$readOnly,
    [Parameter()][array]$modify,
    [Parameter()][array]$ips
)

### whitelist entry
function netbitsToDDN($netBits){
    $maskBits = '1' * $netBits + '0' * (32 - $netBits)
    $octet1 = [convert]::ToInt32($maskBits.Substring(0,8),2)
    $octet2 = [convert]::ToInt32($maskBits.Substring(8,8),2)
    $octet3 = [convert]::ToInt32($maskBits.Substring(16,8),2)
    $octet4 = [convert]::ToInt32($maskBits.Substring(24,8),2)
    return "$octet1.$octet2.$octet3.$octet4"
}

function newWhiteListEntry($cidr, $perm){
    $ip, $netbits = $cidr -split '/'
    if(! $netbits){
        $netbits = '32'
    }
    $maskDDN = netbitsToDDN $netbits
    $whitelistEntry = @{
        "nfsAccess" = $perm;
        "smbAccess" = $perm;
        "s3Access" = $perm;
        "ip"            = $ip;
        "netmaskIp4"    = $maskDDN
    }
    if($allSquash){
        $whitelistEntry['nfsAllSquash'] = $True
    }
    if($rootSquash){
        $whitelistEntry['nfsRootSquash'] = $True
    }
    return $whitelistEntry
}

### add permissions
function addPermission($user, $perms){
    $sid = $null
    if($user -eq 'Everyone'){
        $sid = 'S-1-1-0'
    }else{
        $domain, $domainuser = $user.split('\')
        $principal = api get "activeDirectory/principals?domain=$domain&includeComputers=true&search=$domainuser" | Where-Object fullName -eq $domainuser
        if($principal){
            $sid = $principal.sid
        }else{
            Write-Warning "User $user not found" -ForegroundColor Yellow
            exit 1
        }
    }
    $permission = @{
        "sid" = $sid;
        "type" = "kAllow";
        "mode" = "kFolderSubFoldersAndFiles";
        "access" = $perms
    }
    $newView.sharePermissions += $permission
}

if(! $deleteView -and ! $viewName){
    Write-Host "-viewName is required" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### Existing view
$existingView = api get views/$newName -quiet
if($deleteView){
    Write-Host "Deleting view $newName"
    if($existingView){
        $null = api delete views/$newName
    }
    exit
}else{
    if($existingView){
        Write-Host "View $newName already exists" -ForegroundColor Yellow
        exit
    }
}    

### search for view to clone
$searchResults = api get /searchvms?entityTypes=kView`&vmName=$viewName
$viewResult = $searchResults.vms | Where-Object { $_.vmDocument.objectName -ieq $viewName }

if ($viewResult) {

    $doc = $viewResult[0].vmDocument
    $versions = $doc.versions

    if($vaultName){
        $versions = $versions | Where-Object { $vaultName -in $_.replicaInfo.replicaVec.target.archivalTarget.name }
    }

    if($versions){
        if($backupDate -match ':' -or $showVersions){
            $groups = $versions | Group-Object -Property {(usecsToDate $_.snapshotTimestampUsecs).ToString('yyyy/MM/dd HH:mm')}
        }else{
            $groups = $versions | Group-Object -Property {(usecsToDate $_.snapshotTimestampUsecs).ToString('yyyy/MM/dd')}
        }
        if($showVersions -or $showDates){
            $groups | Format-Table -Property @{l='Available Dates';e={$_.Name}}
            exit 0
        }
        if($backupDate){
            $group = $groups | Where-Object { $_.Name -eq $backupDate }
            if(! $group){
                write-host "No backups from that date!" -ForegroundColor Yellow
                exit 1
            }
            $version = $group.Group[0]
        }else{
            $version = $versions[0]
        }
    }else{
        write-host "No backups available!" -ForegroundColor Yellow
        exit 1
    }

    $replicas = $version.replicaInfo.replicaVec

    $view = api get views/$($doc.objectName)?includeInactive=True

    $cloneTask = @{
        "name"       = "Clone-View_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
        "objects"    = @(
            @{
                "jobUid"         = $doc.objectId.jobUid;
                "jobId"          = $doc.objectId.jobId;
                "jobInstanceId"  = $version.instanceId.jobInstanceId;
                "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                "entity"         = $doc.objectId.entity; 
            }
        )
        "viewName"   = $newName;
        "action"     = 5;
        "viewParams" = @{
            "sourceViewName"        = $view.name;
            "cloneViewName"         = $newName;
            "viewBoxId"             = $view.viewBoxId;
            "viewId"                = $doc.objectId.entity.id;
            "qos"                   = $view.qos;
            "description"           = $view.description;
            "allowMountOnWindows"   = $view.allowMountOnWindows;
            "storagePolicyOverride" = $view.storagePolicyOverride;
        }
    }

    if($vaultName -or $replicas[0].target.type -ne 1){
        $archivalTarget = ($replicas | Where-Object {$_.target.archivalTarget.name -eq 'S3'})[0].target.ArchivalTarget
        $cloneTask.objects[0]['archivalTarget'] = $archivalTarget
    }

    $cloneOp = api post /clone $cloneTask
    if ($cloneOp) {
        "Cloning {0} from {1}" -f $newName, $viewName
    }

    $newView = $null
    while(1){
        Start-Sleep 5
        $newView = api get views/$newName -quiet
        if($newView){
            break
        }
    }

    # add whitelist entries
    if($ips.Count -gt 0){
        Write-Host "Updating subnet whitelist..."
        if(! $newView.PSObject.Properties['subnetWhitelist']){
            setApiProperty -object $newView -name 'subnetWhitelist' -value @()
        }
        foreach($cidr in $ips){
            $ip, $netbits = $cidr -split '/'
            if(! $netbits){
                $netbits = '32'
            }
            $newView.subnetWhitelist = @($newView.subnetWhiteList | Where-Object ip -ne $ip)
            $newView.subnetWhitelist = @($newView.subnetWhiteList +(newWhiteListEntry $cidr $perm))
        }
    }
    
    # set SMB permissions
    if($readOnly -or $readWrite -or $modify -or $fullControl){
        Write-Host "updating SMB permissions..."
        $newView.sharePermissions = @()
        foreach($user in $readWrite){
            addPermission $user 'kReadWrite'
        }
        
        foreach($user in $fullControl){
            addPermission $user 'kFullControl'
        }
        
        foreach($user in $readOnly){
          addPermission $user 'kReadOnly'
        }
        
        foreach($user in $modify){
          addPermission $user 'kModify'
        }
        $updated = $True
    }
    $null = api put views $newView
}else{
    write-host "View $viewName Not Found" -ForegroundColor Yellow
}
