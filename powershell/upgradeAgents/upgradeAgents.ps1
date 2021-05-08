### usage: ./upgradeAgents.ps1 -vip 192.168.1.198 -username admin -domain local

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][array]$serverNames,  # optional names of servers to protect (comma separated)
    [Parameter()][string]$serverList = '',  # optional text file of servers to protect (one pr line)
    [Parameter()][switch]$all,
    [Parameter()][switch]$upgrade
)

# gather list of servers to add to job
$serversToUpgrade = @()
foreach($server in $serverNames){
    $serversToUpgrade += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $servers = Get-Content $serverList
        foreach($server in $servers){
            $serversToUpgrade += [string]$server
        }
    }else{
        Write-Warning "Server list $serverList not found!"
        exit
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

Write-Host "`nGetting status of agents...`n"

### get Physical Servers
$sources = api get protectionSources?environment=kPhysical

### find upgradable agents and add them to the request list
$agentIds = @()
foreach($source in $sources){
    foreach($node in $source.nodes | Sort-Object -Property {$_.protectionSource.name}){
        $serverName = $node.protectionSource.name
        if($all -or ($serverName -in $serversToUpgrade)){
            foreach($agent in $node.protectionSource.physicalProtectionSource.agents){
                if($agent.upgradability -eq 'kUpgradable'){
                    if($upgrade){
                        $agentIds = $agentIds + $agent.id
                        Write-Host "  $serverName -> Upgrading..."
                    }else{
                        Write-Host "  $serverName`t(Upgradable)"
                    }
                }else{
                    Write-Host "  $serverName`t(Current)"
                }
            }
        }
    }
}

### request the agent upgrades
if($upgrade -and ($agentIds.Count -gt 0)){
    $thisUpgrade = @{'agentIds' = $agentIds}
    $null = api post physicalAgents/upgrade $thisUpgrade
}
""
