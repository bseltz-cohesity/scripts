# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$serverName,
    [Parameter()][string]$serverList,
    [Parameter()][array]$excludeServerName,
    [Parameter()][string]$excludeServerList,
    [Parameter()][switch]$showUnprotectedOnly
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "oracleProtectionStatus-$($cluster.name)-$dateString.csv"

# headings
"""Server Name"",""Instance Name"",""Protected""" | Out-File -FilePath $outfileName


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


$serverNames = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $false)
$excludeServerNames = @(gatherList -Param $excludeServerName -FilePath $excludeServerList -Name 'excluded servers' -Required $false)

$sources = api get protectionSources?environments=kOracle

if($serverNames.Count -gt 0){
    $notfoundServers = $serverNames | Where-Object {$_ -notin $sources.nodes.protectionSource.name}
    if($notfoundServers){
        Write-Host "Servers not found $($notfoundServers -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

foreach($server in $sources.nodes | Sort-Object -Property {$_.protectionSource.name}){
    if($serverNames.Count -eq 0 -or $server.protectionSource.name -in $serverNames){
        if($server.protectionSource.name -notin $excludeServerNames){
            foreach($instance in $server.applicationNodes | Sort-Object -Property {$_.protectionSource.name}){
                $instanceName = $instance.protectionSource.name
                $protected = $false
                $protectedText = "*** not protected ***"
                if($instance.protectedSourcesSummary[0].PSObject.Properties['leavesCount'] -and $instance.protectedSourcesSummary[0].leavesCount -gt 0){
                    $protected = $True
                    $protectedText = 'protected'
                }
                if(!$showUnprotectedOnly -or $protected -eq $false){
                    Write-Host "$($server.protectionSource.name)/$instanceName - $protectedText"
                    """$($server.protectionSource.name)"",""$instanceName"",""$protected""" | Out-File -FilePath $outfileName -Append
                }
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
