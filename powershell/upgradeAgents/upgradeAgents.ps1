### usage: ./agentVersions.ps1 -vip 192.168.1.198 -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][array]$clusterName,
    [Parameter()][array]$agentName,
    [Parameter()][string]$agentList,
    [Parameter()][string]$osType,
    [Parameter()][switch]$skipWarnings,
    [Parameter()][switch]$upgrade,
    [Parameter()][switch]$skipCurrent,
    [Parameter()][switch]$refresh,
    [Parameter()][Int]$timeout = 35,
    [Parameter()][Int]$throttle = 12,
    [Parameter()][Int]$sleepTime = 60
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$agentNames = @(gatherList -Param $agentName -FilePath $agentList -Name 'agents' -Required $false)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# outfile
$dateString = (get-date).ToString('yyyy-MM-dd_HH-mm-ss')
$csvFile = "agentUpgrades-$dateString.csv"
"Cluster Name,Cluster Version,Agent Name,Agent Version,OS Type,OS Name,Status,Error Message" | Out-File -FilePath $csvFile

$reportNextSteps = $False

foreach($v in $vip){
    ### authenticate
    "`nConnecting to $v"
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -noPromptForPassword $noPrompt -mfaCode $mfaCode
    if(!$USING_HELIOS){
        ""
    }
    if($USING_HELIOS -and ! $clusterName){
        $clusterName = @((heliosClusters).name)
    }

    if(!$cohesity_api.authorized){
        Write-Host "$v Not authenticated" -ForegroundColor Yellow
    }else{
        if(!$USING_HELIOS){
            $clusterName = @((api get cluster).name)
        }
        foreach($cluster in $clusterName){
            if($USING_HELIOS){
                "`nConnecting to $cluster`n"
                $null = heliosCluster $cluster
            }
            # main
            $cluster = api get cluster
            $nodes = api get "protectionSources/registrationInfo?environments=kPhysical&allUnderHierarchy=true"
            $nodesFound = 0
            $nodesCounted = 0
            $nodesUpgraded = 0
            foreach($node in $nodes.rootNodes | Sort-Object -Property {$_.rootNode.physicalProtectionSource.name}){
                $nodesFound += 1
                $tenant = $null
                $errorMessage = $null
                $errors = $null
                $agentIds = @()
                $name = $node.rootNode.physicalProtectionSource.name
                
                if($node.rootNode.PSObject.Properties['entityPermissionInfo']){
                    $tenant = $node.rootNode.entityPermissionInfo.tenant.name
                }
                $errorMessage = $node.registrationInfo.authenticationErrorMessage
                if($errorMessage){
                    $errorMessage = $errorMessage.split(",")[0].split("`n")[0]
                }else{
                    $errorMessage = $node.registrationInfo.refreshErrorMessage
                }
                if($errorMessage){
                    $errorMessage = $errorMessage.split(",")[0].split("`n")[0]
                }
                if($agentNames.Count -eq 0 -or $name -in $agentNames){
                    $version = 'unknown'
                    $hostType = 'unknown'
                    $osName = 'unknown'
                    $status = 'unknown'
                    if($node.rootNode.physicalProtectionSource.agents.Count -gt 0){
                        $version = $node.rootNode.physicalProtectionSource.agents[0].version
                        $hostType = $node.rootNode.physicalProtectionSource.hostType.subString(1)
                        $osName = $node.rootNode.physicalProtectionSource.osName
                        foreach($agent in $node.rootNode.physicalProtectionSource.agents){
                            if($agent.upgradability -eq "kUpgradable"){
                                $status = 'upgradable'
                                $agentIds = @($agentIds + $agent.id | Sort-Object -Unique)
                            }else{
                                $status = 'current'
                            }
                            if(!$osType -or $osType -eq $hostType){
                                if($agentIds.Count -gt 0 -or $refresh){
                                    if($errorMessage){
                                        $errors = "(warning: registration/refresh errors)"
                                    }
                                    if(!$skipWarnings -or !$errors){
                                        $nodesCounted += 1
                                        if($upgrade -or $refresh){
                                            if($upgrade){
                                                "    {0} ({1}): upgrading ...  {2}" -f $name, $hostType, $errors
                                                $thisUpgrade = @{"agentIds" = @($agentIds)}
                                            }else{
                                                "    {0} ({1}): refreshing ...  {2}" -f $name, $hostType, $errors
                                            }
                                            if($tenant){
                                                impersonate $tenant
                                            }
                                            if($upgrade){
                                                $result = api post physicalAgents/upgrade $thisUpgrade
                                                $nodesUpgraded += 1
                                                if($nodesUpgraded % $throttle -eq 0){
                                                    "    sleeping $sleepTime seconds"
                                                    Start-Sleep $sleepTime
                                                }
                                            }else{
                                                $result = api post "protectionSources/refresh/$($node.rootNode.id)"  # -timeout $timeout -quiet
                                            }
                                            if($tenant){
                                                switchback
                                            }
                                        }else{
                                            "    {0} ({1}): {2} *** {3}" -f $name, $hostType, $status, $errors
                                            $reportNextSteps = $True
                                        }
                                    }
                                }else{
                                    if(!$skipCurrent){
                                        $nodesCounted += 1
                                        if(!$upgrade){
                                            "    {0} ({1}): {2}  {3}" -f $name, $hostType, $status, $errors
                                        }
                                    }
                                }
                                "{0},{1},{2},{3},{4},{5},{6},{7}" -f $cluster.name, $cluster.clusterSoftwareVersion, $name, $version, $hostType, $osName, $status, $errorMessage | Out-File -FilePath $csvFile -Append
                            }         
                        }       
                    }
                }
            }
            if($nodesFound -eq 0){
                "    No physical protection sources found"
            }elseif($nodesCounted -eq 0){
                "    Nothing to do"
            }
        }
    }
}
if($reportNextSteps){
    "`nTo perform the upgrades, rerun the script with the -upgrade switch"
}
""
