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
    [Parameter()][switch]$makeSourceCache,
    [Parameter()][switch]$migratePermissions,
    [Parameter()][string]$defaultPassword = 'Pa$$w0rd',
    [Parameter()][int]$pageSize = 10000
)

$script:idIndex = @{}
$script:nameIndex = @{}

function indexSource($rootNode, $new){
    $fqn = "/$($rootNode.environment):$($rootNode.name)"
    function get_nodes($obj, $fqn){
        if($new){
            $script:nameIndex["$fqn"] = $obj.protectionSource.id
        }else{
            $script:idIndex["$($obj.protectionSource.id)"] = $fqn
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                get_nodes $node "$fqn/$($node.protectionSource.name)/"
            }
        }
        if($obj.PSObject.Properties['applicationNodes']){
            foreach($node in $obj.applicationNodes){
                get_nodes $node "$fqn/$($node.protectionSource.name)/"
            }
        }
    }
    $sourceId = $rootNode.id
    $source = api get "protectionSources?pageSize=$pageSize&nodeId=$sourceId&id=$sourceId&includeVMFolders=true&includeSystemVApps=true&includeEntityPermissionInfo=false&allUnderHierarchy=false"
    $cursor = $source.entityPaginationParameters.beforeCursorEntityId
    while(1){
        get_nodes $source "$fqn"
        if($cursor){
            $lastCursor = $cursor
            $source = api get "protectionSources?pageSize=$pageSize&nodeId=$sourceId&id=$sourceId&includeVMFolders=true&includeSystemVApps=true&includeEntityPermissionInfo=false&allUnderHierarchy=false&afterCursorEntityId=$cursor"
            $cursor = $source.entityPaginationParameters.beforeCursorEntityId
            if($cursor -eq $lastCursor){
                break
            }
        }else{
            break
        }
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$groupRestrictions = @()
$userRestrictions = @()

if(!$makeSourceCache){

    Write-Host "`nLoading source from cache..."
    # load data from cache
    if((Test-Path -Path "cacheRoles-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheUsers-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheGroups-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheGroupRestrictions-$sourceCluster.json" -PathType Leaf) -and
       (Test-Path -Path "cacheUserRestrictions-$sourceCluster.json" -PathType Leaf)){
        $sourceRoles = Get-Content -Path "cacheRoles-$sourceCluster.json" | ConvertFrom-Json
        $sourceUsers = Get-Content -Path "cacheUsers-$sourceCluster.json" | ConvertFrom-Json
        $sourceGroups = Get-Content -Path "cacheGroups-$sourceCluster.json" | ConvertFrom-Json
        $groupRestrictions = Get-Content -Path "cacheGroupRestrictions-$sourceCluster.json" | ConvertFrom-Json
        $userRestrictions = Get-Content -Path "cacheUserRestrictions-$sourceCluster.json" | ConvertFrom-Json
    }else{
        $makeSourceCache = $True
    }
    if($migratePermissions){
        if((Test-Path -Path "cacheIdIndex-$sourceCluster.json" -PathType Leaf)){
            $script:idIndex = Get-Content -Path "cacheIdIndex-$sourceCluster.json" | ConvertFrom-Json
        }else{
            $makeSourceCache = $True
        }
    }
}

if($makeSourceCache){

    Write-Host "`nConnecting to source cluster..."
    apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword -quiet
    
    Write-Host "Indexing source info..."
    # collect info from source cluster
    $sourceRoles = api get roles
    $sourceUsers = api get users
    $sourceGroups = api get groups

    foreach($group in $sourceGroups | Where-Object restricted -eq $True){
        $restrictions = api get principals/protectionSources?sids=$($group.sid)
        $groupRestrictions = @($groupRestrictions + $restrictions)
    }
    foreach($user in $sourceUsers | Where-Object restricted -eq $True){
        $restrictions = api get principals/protectionSources?sids=$($user.sid)
        $userRestrictions = @($userRestrictions + $restrictions)
    }

    if($migratePermissions){
        $sources = api get protectionSources/registrationInfo
        foreach($rootNode in $sources.rootNodes){
            indexSource $rootNode.rootNode
        }
    }

    # save data to cache
    $sourceRoles | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheRoles-$sourceCluster.json"
    $sourceUsers | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheUsers-$sourceCluster.json"
    $sourceGroups | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheGroups-$sourceCluster.json"
    $groupRestrictions | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheGroupRestrictions-$sourceCluster.json"
    $userRestrictions | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheUserRestrictions-$sourceCluster.json"
    if($migratePermissions){
        $script:idIndex | ConvertTo-Json -Depth 99 | Out-File -FilePath "cacheIdIndex-$sourceCluster.json"
        $script:idIndex = $script:idIndex | ConvertTo-Json -Depth 99 | ConvertFrom-Json
    }
}

Write-Host "Connecting to target cluster..."
apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -quiet

Write-Host "Indexing target info..."
$targetRoles = api get roles
$targetUsers = api get users
$targetGroups = api get groups
$targetViews = api get views

if($migratePermissions){
    $sources = api get protectionSources/registrationInfo
    foreach($rootNode in $sources.rootNodes){
        indexSource $rootNode.rootNode $True
    }
}

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
        if(!$migratePermissions){
            $user.restricted = $False
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
        if(!$migratePermissions){
            $group.restricted = $False
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
        $targetSourceName = $script:idIndex."$($protectionSource.id)"
        $targetSourceId = $script:nameIndex["$targetSourceName"]
        if($targetSourceId){
            $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds + $targetSourceId)
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

if($migratePermissions){
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
}
