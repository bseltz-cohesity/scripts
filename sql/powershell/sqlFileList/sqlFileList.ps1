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
    [Parameter()][string]$clusterName,
    [Parameter()][switch]$protectedOnly
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

Write-Host "`nGathering SQL file info...`n"

$cluster = api get cluster
$outfileName = "sqlFiles-$($cluster.name).csv"

"""Server Name"",""DB Name"",""Protected"",""File Path"",""File Extension"",""Size Bytes"",""File Type""" | Out-File -FilePath $outfileName -Encoding utf8

$sqlHosts = api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kSQL"

foreach($sqlHost in $sqlHosts.rootNodes | Sort-Object -Property {$_.rootNode.name}){
    $source = api get protectionSources?id=$($sqlHost.rootNode.id)
    $serverName = $source.protectionSource.name
    Write-Host "$serverName"
    foreach($instance in $source.applicationNodes | Sort-Object -Property {$_.protectionSource.name}){
        foreach($db in $instance.nodes | Sort-Object -Property {$_.protectionSource.name}){
            $dbName = $db.protectionSource.name
            $protected = $False
            if($db.protectedSourcesSummary[0].PSObject.Properties['leavesCount'] -and $db.protectedSourcesSummary[0].leavesCount -eq 1){
                $protected = $True
            }
            if(!$protectedOnly -or $protected -eq $True){
                foreach($dbFile in $db.protectionSource.sqlProtectionSource.dbFiles){
                    $dbFileName = $dbFile.fullPath.split('\')[-1]
                    $ext = ''
                    if($dbFileName.Contains('.')){
                        $ext = $dbFileName.split('.')[-1]
                    }
                    Write-Host "    $dbName"
                    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}""" -f $serverName, $dbName, $protected, $dbFile.fullPath, $ext, $dbFile.sizeBytes, $dbFile.fileType | Out-File -FilePath $outfileName -Append
                }
            }
        }
    }
}

Write-Host "`nOutput saved to $outfilename`n"
