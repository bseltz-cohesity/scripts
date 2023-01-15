### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'MiB'
)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "netappVolumes-$($cluster.name)-$dateString.csv"
$outfileName2 = "netappProtectionGroups-$($cluster.name)-$dateString.csv"
# headings
$global:outtext = """Source Name"",""vServer Name"",""Volume Name"",""Path"",""Capacity ($unit)"",""Used ($unit)"",""State"",""Protected"",""Protection Group""`n" # | Out-File -FilePath $outfileName -Encoding utf8
"""Protection Group"",""Protected Size ($unit)""" | Out-File -FilePath $outfileName2 -Encoding utf8

$sources = api get "protectionSources?environments=kNetapp&isActive=true&isDeleted=false"
$jobs = api get -v2 "data-protect/protection-groups?environments=kNetapp&isActive=true&isDeleted=false"
$sizes = @{}

function walkNodes($source, $sourceName, $vServerName, $ancestors){    
    foreach($node in ($source.nodes | Sort-Object -Property {$_.protectionSource.name})){
        if($node.PSObject.Properties['nodes']){
            # this is a vserver
            Write-Host "    $($node.protectionSource.name)"
            walkNodes $node $sourceName $node.protectionSource.name @($source.protectionSource.id, $node.protectionSource.id)
        }else{
            if($node.protectionSource.netappProtectionSource.type -eq 'kVolume'){
                $volumeName = $node.protectionSource.netappProtectionSource.name
                $capacityBytes = toUnits $node.protectionSource.netappProtectionSource.volumeInfo.capacityBytes
                $usedBytes = toUnits $node.protectionSource.netappProtectionSource.volumeInfo.usedBytes
                $state = $node.protectionSource.netappProtectionSource.volumeInfo.state.subString(1)
                $path = $node.protectionSource.netappProtectionSource.volumeInfo.junctionPath
                if($node.protectedSourcesSummary[0].leavesCount){
                    $protected = $True
                }else{
                    $protected = $False
                }
                $protectedBy = @()
                foreach($ancestor in $ancestors){
                    $protectedBy = @($protectedBy + @($jobs.protectionGroups | Where-Object {$ancestor -in $_.netappParams.objects.id}))
                    $protectedBy = @($protectedBy | Where-Object {$ancestor -notin $_.netappParams.excludeObjectIds})
                }
                $protectedBy = @($protectedBy | Where-Object {$node.protectionSource.id -notin $_.netappParams.excludeObjectIds})
                $protectedBy = @($protectedBy + @($jobs.protectionGroups | Where-Object {$node.protectionSource.id -in $_.netappParams.objects.id}))
                $ProtectedByText = @()
                foreach($thisProtectedBy in $protectedBy){
                    $protectedByText = @($protectedByText + "$($thisProtectedBy.name) ()")
                    if($thisProtectedBy.name -notin $sizes.Keys){
                        $sizes[$thisProtectedBy.name] = 0
                    }
                    $sizes[$thisProtectedBy.name] += $usedBytes
                }
                Write-Host "        $volumeName"
                # Write-Host "            $($protectedBy.name -join ', ')"
                # Write-Host "            $($protectedBy.id -join ', ')"
                
                $global:outtext = $global:outtext + """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}""`n" -f $sourceName, $vServerName, $volumeName, $path, $capacityBytes, $usedBytes, $state, $protected, ($protectedByText -join ', ') # | Out-File -FilePath $outfileName -Append -Encoding utf8
            }
        }
    }
}

foreach($source in $sources | Sort-Object -Property name){
    Write-Host "`n$($source.protectionSource.name)"
    $sourceName = $source.protectionSource.name
    $sourceType = $source.protectionSource.netappProtectionSource.type
    walkNodes $source $sourceName $sourceName @($source.protectionSource.id)
}

foreach($protectionGroup in $sizes.Keys | Sort-Object){
    $global:outtext = $global:outtext.replace("$protectionGroup ()", "$protectionGroup ($("{0:n0}" -f $($sizes[$protectionGroup])))")
    """{0}"",""{1}""" -f $protectionGroup, $sizes[$protectionGroup] | Out-File -FilePath $outfileName2 -Append -Encoding utf8
}

$global:outtext | Out-File -FilePath $outfileName -Encoding utf8
Write-Host "`nVolume Inventory output to $outfileName"
Write-Host "Protection Groups output to $outfileName2`n"
