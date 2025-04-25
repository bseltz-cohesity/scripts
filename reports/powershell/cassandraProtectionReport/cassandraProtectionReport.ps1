# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][array]$clusterName = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$script:outfilename = "cassandraProtectionReport.csv"
"""Cluster Name"",""Source Name"",""KeySpace Name"",""Table Name"",""Protected"",""Protection Group""" | Out-File -FilePath $script:outfilename -Encoding utf8

$script:noSourcesFound = $True

function report(){

    $cluster = api get cluster
    Write-Host "`n$($cluster.name)"
    $sources = api get "protectionSources/registrationInfo?useCachedData=false&pruneNonCriticalInfo=true&allUnderHierarchy=true&includeExternalMetadata=true&includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false&environments=kCassandra"

    foreach($source in $sources.rootNodes){
        $script:noSourcesFound = $False
        $sourceName = $source.rootNode.cassandraProtectionSource.uuid
        Write-Host "    $sourceName"
        # $source.rootNode | toJson
        $thisSource = api get "protectionSources?_useClientSideExcludeTypesFilter=false&allUnderHierarchy=true&id=$($source.rootNode.id)&includeEntityPermissionInfo=true"
        $protectedObjects = api get "protectionSources/protectedObjects?environment=kCassandra&id=$($source.rootNode.id)&includeRpoSnapshots=false&pruneProtectionJobMetadata=true"
        if($thisSource.PSObject.Properties['nodes']){
            foreach($keyspace in $thisSource.nodes){
                $keySpaceName = $keyspace.protectionSource.cassandraProtectionSource.name
                if($keyspace.PSObject.Properties['nodes']){
                    foreach($table in $keyspace.nodes){
                        $protected = $False
                        $protectionJob = ''
                        $tableName = $table.protectionSource.cassandraProtectionSource.name
                        $protectedObject = $protectedObjects | Where-Object {$_.protectionSource.id -eq $table.protectionSource.id}
                        if($protectedObject){
                            $protected = $True
                            $protectionJob = $protectedObject.protectionJobs[0].name
                        }
                        """$($cluster.name)"",""$sourceName"",""$keySpaceName"",""$tableName"",""$protected"",""$protectionJob""" | Out-File -FilePath $script:outfilename -Append
                    }
                }
            }
        }
    }
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        Write-Host "`n$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if($USING_HELIOS){
        if(! $clusterName){
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName | Sort-Object){
            $null = heliosCluster $c
            report
        }
    }else{
        report
    }
}

if($script:noSourcesFound -eq $True){
    Write-Host "`nNo Cassandra Protection Sources Found`n"
}else{
    Write-Host "`nOutput Saved to $script:outfilename`n"
}
