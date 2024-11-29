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
    [Parameter()][string]$clusterName,
    [Parameter()][switch]$showInstances,
    [Parameter()][switch]$showDatabases
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

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

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

$jobs = api get -v2 "data-protect/protection-groups?environments=kSQL&isActive=true&isDeleted=false"
foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($job.mssqlParams.protectionType -eq 'kFile'){
        $paramName = "fileProtectionTypeParams"
    }elseif($job.mssqlParams.protectionType -eq 'kVolume'){
        $paramName = "volumeProtectionTypeParams"
    }else{
        $paramName = "nativeProtectionTypeParams"
    }
    setApiProperty -object $job -name selections -value @($job.mssqlParams.$paramName.objects.id)
}

$sources = api get protectionSources?environments=kSQL

function getJobName($id){
    if($id -in $jobs.protectionGroups.selections){
        $job = $jobs.protectionGroups | Where-Object {$id -in $_.selections}
        return $job.name
    }
    return $null
}

$cluster = api get basicClusterInfo
$outfile = "sqlJobSelections-$($cluster.name).csv"

"Entity Type,Server Name,Instance Name,Database Name,Protection Group Name,Protection Type,Selection Type" | Out-File -FilePath $outfile

"`nReviewing SQL selections...`n"

foreach($server in $sources.nodes | Sort-Object -Property {$_.protectionSource.name}){
    $unprotectedDB = $False
    $selections = @()
    "$($server.protectionSource.name)"
    $serverJobName = $null
    $selection = 'Unprotected'
    $serverSelected = $false
    $serverJobName = getJobName $server.protectionSource.id
    if($serverJobName){
        $selection = 'Auto'
        $serverSelected = $True
    }
    $serverSelection = @{
        'entityType' = 'Server';
        'serverName' = $server.protectionSource.name;
        'instanceName' = '-';
        'dbName' = '-';
        'jobName' = $serverJobName;
        'selection' = $selection
    }
    $selections = @($selections + $serverSelection)

    foreach($instance in $server.applicationNodes){
        $unprotectedInstance = $True
        $unprotectedDatabase = $false
        $instanceJobName = $null
        $selection = 'Unprotected'
        $instanceSelected = $false
        if($serverSelected){
            $selection = 'Auto'
            $instanceJobName = $serverJobName
            $instanceSelected = $True
        }else{
            $instanceJobName = getJobName $instance.protectionSource.id
            if($instanceJobName){
                $selection = 'Auto'
                $instanceSelected = $True
                $serverSelection.jobName = $instanceJobName
                $serverSelection.selection = 'All'
                $protectedInstance = $True
                $unprotectedInstance = $false
            }
        }
        $instanceSelection = @{
            'entityType' = 'Instance';
            'serverName' = $server.protectionSource.name;
            'instanceName' = $instance.protectionSource.name;
            'dbName' = '-';
            'jobName' = $instanceJobName;
            'selection' = $selection
        }
        $selections = @($selections + $instanceSelection)

        foreach($database in $instance.nodes){
            $selection = 'Unprotected'
            $dbSelected = $false
            $dbJobName = $null
            if($instanceSelected){
                $selection = 'Auto'
                $dbJobName = $instanceJobName
                $dbSelected = $True
            }else{
                $dbJobName = getJobName $database.protectionSource.id
                if($dbJobName){
                    $selection = 'Selected'
                    $instanceSelection.selection = 'All'
                    $instanceSelection.jobName = $dbJobName
                    $serverSelection.selection = 'All'
                    $serverSelection.jobName = $dbJobName
                    $unprotectedInstance = $false
                }else{
                    $unprotectedDatabase = $True
                    $unprotectedDB = $True
                }
            }
            if($showDatabases){
                $selections = @($selections + @{
                    'entityType' = 'Database';
                    'serverName' = $server.protectionSource.name;
                    'instanceName' = $instance.protectionSource.name;
                    'dbName' = $database.protectionSource.name;
                    'jobName' = $dbJobName;
                    'selection' = $selection
                })
            }
        }
        if($unprotectedDatabase -eq $True){
            if($instanceSelection.selection -eq 'All'){
                $instanceSelection.selection = 'Some'
            }
            if($serverSelection.selection -eq 'All'){
                $serverSelection.selection = 'Some'
            }
        }
        if($unprotectedInstance -eq $True){
            if($serverSelection.selection -eq 'All'){
                $serverSelection.selection = 'Some'
            }
        }
    }
    if($unprotectedDB -eq $True){
        if($serverSelection.selection -eq 'All'){
            $serverSelection.selection = 'Some'
        }
    }
    foreach($s in $selections){
        if($s.entityType -notin @('Instance', 'Database') -or $showInstances -or $showDatabases){
            "{0},{1},{2},{3},{4},{5},{6}" -f $s.entityType, $s.serverName, $s.instanceName, $s.dbName, $s.jobName, $job.mssqlParams.protectionType, $s.selection | Out-File -FilePath $outfile -Append
        }       
    }
}

"`nOutput saved to $outfile`n"