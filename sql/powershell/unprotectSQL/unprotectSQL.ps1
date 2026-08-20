# process commandline arguments
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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][array]$serverName,
    [Parameter()][string]$serverList,
    [Parameter()][array]$instanceName,
    [Parameter()][array]$dbName,
    [Parameter()][string]$dbList
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

$serversToAdd = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $True)
$dbsToAdd = @(gatherList -Param $dbName -FilePath $dbList -Name 'databases' -Required $False)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# get the protection job
$job = (api get -v2 data-protect/protection-groups).protectionGroups | Where-Object name -eq $jobName
if(! $job){
    Write-Host "Protection group '$jobName' not found!" -ForegroundColor Yellow
    exit 1
}
if($job.environment -ne 'kSQL'){
    Write-Host "Protection group '$jobName' is not a SQL Server protection group!" -ForegroundColor Yellow
    exit 1
}

$paramName = @{
    'kFile' = 'fileProtectionTypeParams';
    'kVolume' = 'volumeProtectionTypeParams';
    'kNative' = 'nativeProtectionTypeParams'
}
$params = $job.mssqlParams.$($paramName[$job.mssqlParams.protectionType])

if(! $params.PSObject.Properties['excludeFilters'] -or $null -eq $params.excludeFilters){
    setApiProperty -object $params -name 'excludeFilters' -value @()
}

$changesMade = $false

# root SQL source
$sources = api get "protectionSources/registrationInfo?environments=kSQL&includeApplicationsTreeInfo=false"

function isSelected($thisSource){
    $existingSelection = @(@($params.objects | Where-Object {$_.id -eq $thisSource.protectionSource.id}))
    if($existingSelection.Count -gt 0){
        return $True
    }else{
        return $false
    }
}

# remove a source, and any of its (grand)children, from the job's explicit selection list.
# returns $true if anything was actually removed (i.e. the source or any of its children was
# explicitly selected), $false if there was nothing to remove.
function removeSelection($thisSource){
    $beforeCount = $params.objects.Count
    $params.objects = @(@($params.objects | Where-Object {$_.id -ne $thisSource.protectionSource.id}))
    if($thisSource.PSObject.Properties['applicationNodes']){
        foreach($instance in $thisSource.applicationNodes){
            $params.objects = @(@($params.objects | Where-Object {$_.id -ne $instance.protectionSource.id}))
            if($instance.PSObject.Properties['nodes']){
                foreach($node in $instance.nodes){
                    $params.objects = @(@($params.objects | Where-Object {$_.id -ne $node.protectionSource.id}))
                }
            }
        }
    }
    if($thisSource.PSObject.Properties['nodes']){
        foreach($node in $thisSource.nodes){
            $params.objects = @(@($params.objects | Where-Object {$_.id -ne $node.protectionSource.id}))
        }
    }
    if($params.objects.Count -lt $beforeCount){
        $script:changesMade = $true
        return $true
    }
    return $false
}

# add (or refresh) an exclusion filter, used when an item is auto-protected by a parent selection
function addExclusion($filterString){
    $existingFilter = @($params.excludeFilters | Where-Object {$_.filterString -eq $filterString})
    $params.excludeFilters = @(@($params.excludeFilters | Where-Object {$_.filterString -ne $filterString}) + @{'filterString' = $filterString; 'isRegularExpression' = $False})
    if($existingFilter.Count -eq 0){
        $script:changesMade = $true
    }
}

function getInstanceSource($serverSource, $instance){
    if($serverSource.PSObject.Properties['nodes']){
        # 7.3 AAG
        return $serverSource.nodes | Where-Object {$_.protectionSource.name -eq $instance}
    }else{
        return $serverSource.applicationNodes | Where-Object {$_.protectionSource.name -eq $instance}
    }
}

foreach($servername in $serversToAdd){
    $serverSourceRootNode = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $servername}
    if(! $serverSourceRootNode){
        Write-Host "Server $servername not found!" -ForegroundColor Yellow
        continue
    }
    $serverSource = api get "protectionSources?id=$($serverSourceRootNode.rootNode.id)"
    # exclusion filters are case sensitive, so always use the source's exact registered name
    $exactServerName = $serverSource.protectionSource.name

    if($instanceName.Count -eq 0 -and $dbsToAdd.Count -eq 0){
        # remove the entire server from the job. If the server itself isn't explicitly
        # selected, this still unselects any of its child instances/databases that are.
        if(removeSelection $serverSource){
            Write-Host "Removing $servername (and any selected child instances/databases) from protection"
        }else{
            Write-Host "$servername is not currently protected by this job" -ForegroundColor Yellow
        }
    }elseif($dbsToAdd.Count -eq 0){
        # remove one or more instances
        foreach($instance in $instanceName){
            $instanceSource = getInstanceSource $serverSource $instance
            if(! $instanceSource){
                Write-Host "Instance $instance not found on server $servername" -ForegroundColor Yellow
                continue
            }
            if(isSelected $serverSource){
                # the instance is only protected because the whole server is selected (auto-protection)
                $exactInstanceName = $instanceSource.protectionSource.name
                addExclusion "$exactServerName/$exactInstanceName/"
                Write-Host "Excluding $exactServerName/$exactInstanceName (auto-protected via $exactServerName selection)"
            }else{
                # if the instance itself isn't explicitly selected, this still unselects
                # any of its child databases that are
                if(removeSelection $instanceSource){
                    Write-Host "Removing $servername/$instance (and any selected child databases) from protection"
                }else{
                    Write-Host "$servername/$instance is not currently protected by this job" -ForegroundColor Yellow
                }
            }
        }
    }else{
        # remove one or more databases
        $instancesToProcess = $instanceName
        if($instancesToProcess.Count -eq 0){
            $instancesToProcess = @('MSSQLSERVER')
        }
        foreach($instance in $instancesToProcess){
            $instanceSource = getInstanceSource $serverSource $instance
            if(! $instanceSource){
                Write-Host "Instance $instance not found on server $servername" -ForegroundColor Yellow
                continue
            }
            foreach($thisDBName in $dbsToAdd){
                $dbSource = $instanceSource.nodes | Where-Object {$_.protectionSource.name -eq "$($instanceSource.protectionSource.name)/$thisDBName"}
                if(! $dbSource){
                    Write-Host "$thisDBName not found in $servername/$instance" -ForegroundColor Yellow
                    continue
                }
                if((isSelected $serverSource) -or (isSelected $instanceSource)){
                    # the database is only protected because a parent (server or instance) is selected (auto-protection).
                    # dbSource.protectionSource.name is already "<exact instance name>/<exact db name>"
                    $exactFilterString = "$exactServerName/$($dbSource.protectionSource.name)"
                    addExclusion $exactFilterString
                    Write-Host "Excluding $exactFilterString (auto-protected via parent selection)"
                }else{
                    if(removeSelection $dbSource){
                        Write-Host "Removing $servername/$instance/$thisDBName from protection"
                    }else{
                        Write-Host "$servername/$instance/$thisDBName is not currently protected by this job" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
}

if(! $changesMade){
    Write-Host "No changes made. Exiting without committing changes." -ForegroundColor Yellow
    exit 1
}

Write-Host "Updating job $jobName..."
$null = api put -v2 data-protect/protection-groups/$($job.id) $job