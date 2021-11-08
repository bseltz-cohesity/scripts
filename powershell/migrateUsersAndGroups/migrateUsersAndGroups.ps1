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

function getObjectByName($sources, $objectName, $parentId=$null){
    $global:_object_id = $null
    $global:object = $null

    function get_nodes($obj, $parentId=$null){
        if($obj.protectionSource.name -eq $objectName){
            if($null -eq $parentId -or $obj.protectionSource.parentId -eq $parentId){
                $global:_object_id = $obj.protectionSource.id
                $global:object = $obj
                break
            }
        }
        if($obj.name -eq $objectName){
            if($null -eq $parentId -or $obj.protectionSource.parentId -eq $parentId){
                $global:_object_id = $obj.id
                $global:object = $obj
                break
            }
        }
        if($obj.PSObject.Properties['nodes'] -and $obj.protectionSource.name -ne 'Registered Agents'){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object_id){
                    get_nodes $node -parentId $parentId
                }
            }
        }
        if($obj.PSObject.Properties['applicationNodes']){
            foreach($node in $obj.applicationNodes){
                if($null -eq $global:_object_id){
                    get_nodes $node -parentId $parentId
                }
            }
        }
    }
    
    foreach($source in $sources){
        if($null -eq $global:_object_id){
            get_nodes $source -parentId $parentId
        }
    }
    return $global:object
}

function getObjectById($objectId, $sources){
    $global:_object = $null
    function get_nodes($obj){
        if($obj.protectionSource.id -eq $objectId){
            $global:_object = $obj
            break
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object){
                    get_nodes $node
                }
            }
        }
    }

    foreach($source in $sources){
        if($null -eq $global:_object){
            get_nodes $source
        }
    }
    return $global:_object
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
        $sourceRoles = Get-Content -Path "cacheRoles-$sourceCluster.json" | ConvertFrom-Json -Depth 99
        $sourceUsers = Get-Content -Path "cacheUsers-$sourceCluster.json" | ConvertFrom-Json -Depth 99
        $sourceGroups = Get-Content -Path "cacheGroups-$sourceCluster.json" | ConvertFrom-Json -Depth 99
        $sourceProtectionSources = Get-Content -Path "cacheProtectionSources-$sourceCluster.json" | ConvertFrom-Json -Depth 99
        $groupRestrictions = Get-Content -Path "cacheGroupRestrictions-$sourceCluster.json" | ConvertFrom-Json -Depth 99
        $userRestrictions = Get-Content -Path "cacheUserRestrictions-$sourceCluster.json" | ConvertFrom-Json -Depth 99
    }else{
        Write-Host "Cache not found, please use -makeCache to create one" -ForegroundColor Yellow
        exit
    }
}

"Connecting to target cluster..."
apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -quiet

$targetRoles = api get roles
$targetUsers = api get users
$targetGroups = api get groups
$targetProtectionSources = api get protectionSources
$targetViews = api get views

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
            $parentSource = getObjectById -objectId $protectionSource.parentId -sources $sourceProtectionSources
            $targetParentSource = getObjectByName -sources $targetProtectionSources -objectName $parentSource.protectionSource.name
            $targetParentSourceId = $targetParentSource.protectionSource.id
            $targetSource = getObjectByName -sources $targetProtectionSources -objectName $protectionSource.name -parentId $targetParentSourceId
            if($targetSource){
                $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds + $targetSource.protectionSource.id)
            }
        }else{
            $targetSource = getObjectByName -sources $targetProtectionSources -objectName $protectionSource.name
            if($targetSource){
                $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds + $targetSource.protectionSource.id)
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
