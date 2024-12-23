
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter()][string]$ip,
    [Parameter()][string]$groupName,
    [Parameter()][string]$connectionName,
    [Parameter()][switch]$ungroup,
    [Parameter()][switch]$deleteGroup,
    [Parameter()][switch]$wait
)

# validate parameters
if(! $ip -and ! $connectionName){
    Write-Host "Must specify either -ip or -connectionName" -ForegroundColor Yellow
    exit
}
if($delete -and ! $groupName){
    Write-Host "-groupName must be specified" -ForegroundColor Yellow
    exit
}

$greenCheck = "$([char]0x1b)[92m$([char]8730)"
$redX = "$([char]0x1b)[91m×"
$greenPlus = "$([char]0x1b)[92m+"
$statusIcon = @{
    "Healthy" = $greenCheck;
    "Unhealthy" = $redX
}

. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to CCS ===========================================
Write-Host "Connecting to Cohesity Cloud..."
apiauth -username $username -passwd $password
# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
$userInfo = api get /mcm/userInfo
$tenantId = $userInfo.user.profiles[0].tenantId
# ===============================================================

# get list of SaaS Connections
$rigelGroups = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&fetchConnectorGroups=true"

if($connectionName){
    # get existing rigel group
    $rigelGroup = $rigelGroups.rigelGroups | Where-Object {$_.groupName -eq $connectionName}
    if(! $rigelGroup){
        Write-Host "SaaS Connection $connectionName not found" -ForegroundColor Yellow
        exit
    }
}

if($ip){
    $rigelGroup = $rigelGroups.rigelGroups | Where-Object {$ip -in $_.connectorGroups.connectors.rigelIp}
    if( ! $rigelGroup){
        Write-Host "SaaS Connector $ip not found in any connection" -ForegroundColor Yellow
        exit
    }
}

$connectorGroups = $rigelGroup.connectorGroups
$ungrouped = $connectorGroups | Where-Object {$_.isUngroup -eq $True}
$namedGroups = $connectorGroups | Where-Object {$_.isUngroup -eq $false}

$updateStatus = ''
if($rigelGroup.PSObject.Properties['connectorGroupRequestId']){
    $updateStatus = ' *** UPDATING ***'
    Write-Host "`n$($rigelGroup.groupName) ($($rigelGroup.regionId))$updateStatus" -ForegroundColor Yellow
}else{
    Write-Host "`n$($rigelGroup.groupName) ($($rigelGroup.regionId))$updateStatus"
}

function displayGroup($rigelGroup){
    $connectorGroups = $rigelGroup.connectorGroups
    $ungrouped = $connectorGroups | Where-Object {$_.isUngroup -eq $True}
    $namedGroups = $connectorGroups | Where-Object {$_.isUngroup -eq $false}
    # display connector groups ======================================================
    foreach($group in $namedGroups | Sort-Object -Property connectorGroupName){
        Write-Host "`n  $($group.connectorGroupName)"
        foreach($connector in $group.connectors){
            $status = 'Unhealthy'
            if($connector.controlPlaneConnectionStatus -eq 'Healthy' -and $connector.dataPlaneConnectionStatus -eq 'Healthy'){
                $status = 'Healthy'
            }
            Write-Host "    $($statusIcon[$status]) " -NoNewLine
            Write-Host "$($connector.rigelName) $($connector.rigelIp)"
        }
    }
    foreach($group in $ungrouped | Sort-Object -Property connectorGroupName){
        Write-Host "`n  Ungrouped"
        foreach($connector in $group.connectors){
            $status = 'Unhealthy'
            if($connector.controlPlaneConnectionStatus -eq 'Healthy' -and $connector.dataPlaneConnectionStatus -eq 'Healthy'){
                $status = 'Healthy'
            }
            Write-Host "    $($statusIcon[$status]) " -NoNewLine
            Write-Host "$($connector.rigelName) $($connector.rigelIp)"
        }
    }
    Write-Host ""
    # =============================================================================
}
displayGroup $rigelGroup

# perform updates

function updateConfigs($groupConfigs, $groupId){
    foreach($groupConfig in $groupConfigs){
        $groupConfig.connectorIds = @($groupConfig.connectorIds | Where-Object {$_ -ne $null})
    }
    $groupConfigs = @($groupConfigs | Where-Object {$_.action -eq 'Delete' -or $_.connectorIds.Count -ne 0})
    # $groupConfigs | toJson
    $response = api put -mcmv2 rigelmgmt/connections @{
        "ConnectionId" = $rigelGroup.groupId;
        "connectorGroupConfigs" = $groupConfigs
    }
    if($wait){
        $updateStatus = ' *** UPDATING ***'
        while($updateStatus -ne ''){
            Start-Sleep 10
            $thisRigelGroup = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&maxRecordLimit=1000&groupId=$groupId&fetchConnectorGroups=true"
            $rigelGroup = $thisRigelGroup.rigelGroups[0]
            $updateStatus = ''
            if($rigelGroup.PSObject.Properties['connectorGroupRequestId']){
                $updateStatus = ' *** UPDATING ***'
            }else{
                displayGroup $rigelGroup
            }
        }
        Write-Host "Update Complete`n"
    }else{
        Write-Host ""
    }
}

if(($ip -and $groupName) -or ($deleteGroup -and $groupName) -or ($ip -and $ungroup)){
    # wait for updates
    if($updateStatus -ne ''){
        Write-Host "Waiting for update to complete..."
    }
    while($updateStatus -ne ''){
        Start-Sleep 10
        $thisRigelGroup = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&maxRecordLimit=1000&groupId=$($rigelGroup.groupId)&fetchConnectorGroups=true"
        $rigelGroup = $thisRigelGroup.rigelGroups[0]
        $updateStatus = ''
        if($rigelGroup.PSObject.Properties['connectorGroupRequestId']){
            $updateStatus = ' *** UPDATING ***'
        }else{
            $connectorGroups = $rigelGroup.connectorGroups
            $ungrouped = $connectorGroups | Where-Object {$_.isUngroup -eq $True}
            $namedGroups = $connectorGroups | Where-Object {$_.isUngroup -eq $false}
        }
    }

    # build group configs
    $groupConfigs = @()
    foreach($namedGroup in $namedGroups){
        $groupConfigs = @($groupConfigs + @{
            "connectorGroupId" = $namedGroup.connectorGroupId;
            "connectorGroupName" = $namedGroup.connectorGroupName;
            "connectorIds" = @($namedGroup.connectors.rigelGuid | Where-Object {$_ -ne $null});
            "isUngroup" = $false;
            "action" = "Update"
        })
    }
    if($ungrouped){
        foreach($connector in $ungrouped.connectors){
            $groupConfigs = @($groupConfigs + @{
                "isUngroup" = $True;
                "action" = "Update";
                "connectorIds" = @($connector.rigelGuid | Where-Object {$_ -ne $null})
            })
        }
    }

    # add or update group
    if($ip -and $groupName){
        # find connector
        $connector = $rigelGroup.connectorGroups.connectors | Where-Object {$_.rigelIp -eq $ip}
        if(! $connector){
            Write-Host "No SaaS Connector found with IP $ip" -ForegroundColor Yellow
            exit
        }

        # remove connector from current group
        $groupConfig = $groupConfigs | Where-Object {$connector.rigelGuid -in $_.connectorIds}
        if($groupConfig.connectorGroupName -eq $groupName){
            Write-Host "SaaS Connector $ip Already in Group $groupName`n"
            exit
        }
        $groupConfig.connectorIds = @($groupConfig.connectorIds | Where-Object {$_ -ne $connector.rigelGuid})

        # add connector to new/existing group
        $groupConfig = $groupConfigs | Where-Object {$_.connectorGroupName -eq $groupName}
        
        if(! $groupConfig){
            # add connector to new group
            $groupConfigs = @($groupConfigs + @{
                "connectorGroupName" = $groupName;
                "action" = "Add";
                "connectorIds" = @($connector.rigelGuid)
            })
        }else{
            # add connector to existing group
            $groupConfig.connectorIds = @($groupConfig.connectorIds + $connector.rigelGuid | Where-Object {$_ -ne $null})
        }
        Write-Host "Adding SaaS Connector $ip to $groupName"
        updateConfigs $groupConfigs $rigelGroup.groupId
        exit
    }

    # delete group
    if($deleteGroup -and $groupName){
        
        $groupConfig = $groupConfigs | Where-Object {$_.connectorGroupName -eq $groupName}
        if(! $groupConfig){
            Write-Host "Group $groupName not found" -ForegroundColor Yellow
            exit
        }else{
            # ungroup connectors from group
            $connectorIds = $groupConfig.connectorIds
            $ungroupConfig = $groupConfigs | Where-Object {$_.isUngroup -eq $True}
            if(! $ungroupConfig){
                $ungroupConfig = @{
                    "isUngroup" = $True;
                    "action" = "Update";
                    "connectorIds" = @($connectorIds)
                }
                $groupConfigs = @($groupConfigs + $ungroupConfig)
            }else{
                $ungroupConfig.connectorIds = @($ungroupConfig.connectorIds + $connectorIds)
            }
            $ungroupConfig.connectorIds = @($ungroupConfig.connectorIds | Where-Object {$_ -ne $null})

            # update group to be deleted
            $groupConfig.action = 'Delete'
            $groupConfig.connectorIds = @()
        }
        Write-Host "Deleting Group $groupName"
        updateConfigs $groupConfigs $rigelGroup.groupId
        exit
    }

    if($ip -and $ungroup){
        # find connector
        $connector = $rigelGroup.connectorGroups.connectors | Where-Object {$_.rigelIp -eq $ip}
        if(! $connector){
            Write-Host "No SaaS Connector found with IP $ip" -ForegroundColor Yellow
            exit
        }

        # remove connector from current group
        $groupConfig = $groupConfigs | Where-Object {$connector.rigelGuid -in $_.connectorIds}
        if($groupConfig.isUngroup -eq $True){
            Write-Host "`nSaaS Connector $ip is ungrouped`n"
            exit
        }
        $groupConfig.connectorIds = @($groupConfig.connectorIds | Where-Object {$_ -ne $connector.rigelGuid})

        # add connector to ungroup
        $ungroupConfig = $groupConfigs | Where-Object {$_.isUngroup -eq $True}
        if(! $ungroupConfig){
            $ungroupConfig = @{
                "isUngroup" = $True;
                "action" = "Update";
                "connectorIds" = @($connector.rigelGuid)
            }
            $groupConfigs = @($groupConfigs + $ungroupConfig)
        }else{
            $ungroupConfig.connectorIds = @($ungroupConfig.connectorIds + $connector.rigelGuid)
        }
        Write-Host "Ungrouping SaaS Connector $ip from $($groupConfig.connectorGroupName)"
        updateConfigs $groupConfigs $rigelGroup.groupId
        exit
    }
}