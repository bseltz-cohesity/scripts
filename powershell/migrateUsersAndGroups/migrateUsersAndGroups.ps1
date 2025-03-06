# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$sourceUser,
    [Parameter()][string]$sourceDomain = 'local',
    [Parameter()][string]$sourcePassword = $null,
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter()][string]$targetUser = $sourceUser,
    [Parameter()][string]$targetDomain = $sourceDomain,
    [Parameter()][string]$targetPassword = $null,
    [Parameter()][switch]$makeCache,
    [Parameter()][switch]$useCache,
    [Parameter()][string]$defaultPassword = 'Pa$$w0rd'
)

function indexObjects($sources, $objectName){
    $global:indexByName = @{}
    $global:indexById = @{}

    function get_nodes($obj){
        $global:indexById[[string]$obj.protectionSource.id] = $obj.protectionSource
        if($obj.protectionSource.name -notin $global:indexByName.Keys){
            $global:indexByName[$obj.protectionSource.name] = @($obj.protectionSource)
        }else{
            if($obj.protectionSource.id -notin $global:indexByName[$obj.protectionSource.name].id){
                $global:indexByName[$obj.protectionSource.name] = @($global:indexByName[$obj.protectionSource.name] + $obj.protectionSource)
            }
        }     
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                get_nodes $node
            }
        }
        if($obj.PSObject.Properties['applicationNodes']){
            foreach($node in $obj.applicationNodes){
                get_nodes $node
            }
        }
    }
    
    foreach($source in $sources){
            get_nodes $source
    }
    return $global:indexByName, $global:indexById
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$groupRestrictions = @()
$userRestrictions = @()

if(!$useCache -or $makeCache){

    "`nConnecting to source cluster..."
    apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword -quiet
    
    # collect info from source cluster
    $sourceRoles = api get roles
    $sourceUsers = api get users
    $sourceGroups = api get groups

    # load data from source cluster
    $sourceProtectionSources = api get protectionSources

    foreach($group in $sourceGroups | Where-Object restricted -eq $True){
        $restrictions = api get principals/protectionSources?sids=$($group.sid)
        $groupRestrictions = @($groupRestrictions + $restrictions)
    }
    foreach($user in $sourceUsers | Where-Object restricted -eq $True){
        $restrictions = api get principals/protectionSources?sids=$($user.sid)
        $userRestrictions = @($userRestrictions + $restrictions)
    }
    if($makeCache){
        # save data to cache
        $sourceRoles | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheRoles-$sourceCluster.json"
        $sourceUsers | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheUsers-$sourceCluster.json"
        $sourceGroups | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheGroups-$sourceCluster.json"
        $sourceProtectionSources | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheProtectionSources-$sourceCluster.json"
        $groupRestrictions | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheGroupRestrictions-$sourceCluster.json"
        $userRestrictions | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheUserRestrictions-$sourceCluster.json"
    }
}else{
    # load data from cache
    if((Test-Path -Path "cacheRoles-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheUsers-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheGroups-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheProtectionSources-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheGroupRestrictions-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheUserRestrictions-$sourceCluster.json" -PathType Leaf)){
        $sourceRoles = Get-Content -Path "cacheRoles-$sourceCluster.json" | ConvertFrom-Json
        $sourceUsers = Get-Content -Path "cacheUsers-$sourceCluster.json" | ConvertFrom-Json
        $sourceGroups = Get-Content -Path "cacheGroups-$sourceCluster.json" | ConvertFrom-Json
        $sourceProtectionSources = Get-Content -Path "cacheProtectionSources-$sourceCluster.json" | ConvertFrom-Json
        $groupRestrictions = Get-Content -Path "cacheGroupRestrictions-$sourceCluster.json" | ConvertFrom-Json
        $userRestrictions = Get-Content -Path "cacheUserRestrictions-$sourceCluster.json" | ConvertFrom-Json
    }else{
        Write-Host "Cache not found, please use -makeCache to create one" -ForegroundColor Yellow
        exit
    }
}

$sourceNameIndex, $sourceIdIndex = indexObjects $sourceProtectionSources

"Connecting to target cluster..."
apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -quiet

$targetRoles = api get roles
$targetUsers = api get users
$targetGroups = api get groups
$targetProtectionSources = api get protectionSources
$targetViews = api get views

$targetNameIndex, $targetIdIndex = indexObjects $targetProtectionSources

# migrate roles
Write-Host "`nMigrating roles..."
foreach($role in $sourceRoles | Where-Object name -notin $targetRoles.name){
    Write-Host "    $($role.name)"
    $null = api post roles $role
}

# migrate users
Write-Host "Migrating users..."
foreach($user in $sourceUsers){
    $existingTargetUser = $targetUsers | Where-Object {$_.username -eq $user.username -and $_.domain -eq $user.domain}
    if(!$existingTargetUser){
        Write-Host "    $($user.username)"
        if($user.domain -eq 'LOCAL'){
            if($user.PSObject.Properties['additionalGroupNames']){
                delApiProperty -object $user -name 'additionalGroupNames'
            }
            if($user.PSObject.Properties['groupRoles']){
                delApiProperty -object $user -name 'groupRoles'
            }
            setApiProperty -object $user -name password -value $defaultPassword
        }
        $null = api post users $user
    }
}

# migrate groups
Write-Host "Migrating groups..."
$targetUsers = api get users
foreach($group in $sourceGroups){
    $existingTargetGroup = $targetGroups | Where-Object {$_.name -eq $group.name -and $_.domain -eq $group.domain}
    if(!$existingTargetGroup){
        if($group.domain -eq 'LOCAL'){
            $group.users = @()
            foreach($username in $group.usernames){
                $user = $targetUsers | Where-Object {$_.username -eq $username -and $_.domain -eq 'LOCAL'}
                if($user){
                    $group.users = @($group.users + $user.sid)
                }
            }
        }
        Write-Host "    $($group.name)"
        $null = api post groups $group
    }
}

function processRestriction($sid, $restriction){
    $newAccess = @{
        "sourcesForPrincipals" = @(
            @{
                "sid"                 = $sid;
                "protectionSourceIds" = @()
                "viewNames"           = @()
            }
        )
    }
    # keep existing restrictions
    $existingRestrictions = api get principals/protectionSources?sids=$sid
    foreach($protectionSource in $existingRestrictions.protectionSources){
        $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds + $protectionSource.id)
    }
    foreach($view in $existingRestrictions.views){
        $newAccess.sourcesForPrincipals[0].viewNames = @($newAccess.sourcesForPrincipals[0].viewNames + $view.name)
    }
    # process new restrictions
    foreach($protectionSource in $restriction.protectionSources){
        $targetSource = $null
        $parentSource = $null
        $targetParentSource = $null
        $targetParentSourceId = $null
        if($protectionSource.PSObject.Properties['parentId']){
            $parentSource = $sourceIdIndex[[string]($protectionSource.parentId)]
            $targetParentSource = $targetNameIndex[$parentSource.name][0]
            $targetParentSourceId = $targetParentSource.id
            $targetSource = $targetNameIndex[$protectionSource.name] | Where-Object parentId -eq $targetParentSourceId
            if($targetSource){
                $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds + $targetSource.id)
            }
        }else{
            $targetSource = $targetNameIndex[$protectionSource.name]
            if($targetSource){
                $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds + $targetSource.id)
            }
        }
    }
    foreach($view in $restriction.views){
        $targetView = $targetViews.views | Where-Object name -eq $view.name
        if($targetView){
            $newAccess.sourcesForPrincipals[0].viewNames = @($newAccess.sourcesForPrincipals[0].viewNames + $targetView.name)
        }
    }
    $null = api put principals/protectionSources $newAccess
}

# migrate object restrictions
Write-Host "Migrating object restrictions..."

# group restrictions
foreach($sid in $groupRestrictions.sid){
    $restriction = $groupRestrictions | Where-Object {$_.sid -eq $sid}
    $sourceGroup = $sourceGroups | Where-Object {$_.sid -eq $sid}
    $targetGroup = $targetGroups | Where-Object {$_.name -eq $sourceGroup.name -and $_.domain -eq $sourceGroup.domain}
    if($targetGroup){
        Write-Host "    $($targetGroup.name)"
        $null = processRestriction $targetGroup.sid $restriction
    }
}

# user restrictions
foreach($sid in $userRestrictions.sid){
    $restriction = $userRestrictions | Where-Object {$_.sid -eq $sid}
    $sourceUserObj = $sourceUsers | Where-Object {$_.sid -eq $sid}
    $targetUserObj = $targetUsers | Where-Object {$_.username -eq $sourceUserObj.username -and $_.domain -eq $sourceUserObj.domain}
    if($targetUserObj){
        Write-Host "    $($targetUserObj.username)"
        $null = processRestriction $targetUserObj.sid $restriction
    }
}
