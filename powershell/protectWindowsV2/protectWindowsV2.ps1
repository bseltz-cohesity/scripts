# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][array]$servers = '',  # optional names of servers to protect (comma separated)
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter()][array]$inclusions = '', # optional paths to exclude (comma separated)
    [Parameter()][string]$inclusionList = '',  # optional list of exclusions in file
    [Parameter()][array]$exclusions = '', # optional paths to exclude (comma separated)
    [Parameter()][string]$exclusionList = '',  # optional list of exclusions in file
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add server to
    [Parameter()][switch]$skipNestedMountPoints,  # if omitted, nested mountpoints will not be skipped
    [Parameter()][switch]$followNasLinks,
    [Parameter()][switch]$allDrives,
    [Parameter()][switch]$replaceRules,
    [Parameter()][switch]$allServers
)

# gather list of servers to add to job
$serversToAdd = @()
foreach($server in $servers){
    $serversToAdd += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $servers = Get-Content $serverList
        foreach($server in $servers){
            $serversToAdd += [string]$server
        }
    }else{
        Write-Warning "Server list $serverList not found!"
        exit
    }
}

# gather inclusion list
$includePaths = @()
foreach($inclusion in $inclusions){
    $includePaths += $inclusion
}
if('' -ne $inclusionList){
    if(Test-Path -Path $inclusionList -PathType Leaf){
        $inclusions = Get-Content $inclusionList
        foreach($inclusion in $inclusions){
            $includePaths += [string]$inclusion
        }
    }else{
        Write-Warning "Inclusions file $inclusionList not found!"
        exit
    }
}
if(! $includePaths){
    if(! $allDrives){
        Write-Host "No include paths specified" -ForegroundColor Yellow
        exit 1
    }
}

# gather exclusion list
$excludePaths = @()
foreach($exclusion in $exclusions){
    $excludePaths += $exclusion
}
if('' -ne $exclusionList){
    if(Test-Path -Path $exclusionList -PathType Leaf){
        $exclusions = Get-Content $exclusionList
        foreach($exclusion in $exclusions){
            $excludePaths += [string]$exclusion
        }
    }else{
        Write-Warning "Exclusions file $exclusionList not found!"
        exit
    }
}

if($skipNestedMountPoints){
    $skip = $True
}else{
    $skip = $false
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get cluster info
$cluster = api get cluster

if($cluster.clusterSoftwareVersion -lt '6.5.1'){
    Write-Host "This script is compatible with Cohesity 6.5.1 and later" -ForegroundColor Yellow
    exit
}

# get the protectionJob
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true"
$job = $jobs.protectionGroups | Where-Object {$_.name -ieq $jobName}

if(!$job){
    Write-Host "Job $jobName not found!" -ForegroundColor Yellow
    exit
}

if($job.environment -ne 'kPhysical' -or $job.physicalParams.protectionType -ne 'kFile'){
    Write-Host "Job $jobName is not a file-based physical job!" -ForegroundColor Yellow
    exit
}

# get physical protection sources
$sources = api get protectionSources?environment=kPhysical

# add sourceIds for new servers
$sourceIds = @($job.physicalParams.fileProtectionTypeParams.objects.id)
$newSourceIds = @()
$sourceName = @{}

foreach($server in $serversToAdd | Where-Object {$_ -ne ''}){
    $server = $server.ToString()
    $node = $sources.nodes | Where-Object { $_.protectionSource.name -eq $server }
    if($node){
        if($node.protectionSource.physicalProtectionSource.hostType -eq 'kWindows'){
            $sourceId = $node.protectionSource.id
            $sourceName[$sourceId] = $node.protectionSource.name
            $sourceIds += $sourceId
            $newSourceIds += $sourceId
        }else{
            Write-Warning "$server is not a Windows host"
        }
    }else{
        Write-Warning "$server is not a registered source"
    }
}

$sourceIds = @($sourceIds | Select-Object -Unique)

$existingParams = $job.physicalParams.fileProtectionTypeParams.objects
$newParams = @()
foreach($sourceId in $sourceIds){
    $node = $sources.nodes | Where-Object { $_.protectionSource.id -eq $sourceId }

    $newServer = $sourceId -in $newSourceIds

    $newParam = @{
        "id"                                   = $sourceId;
        "name"                                 = $node.protectionSource.name;
        "filePaths"                            = @();
        "usesPathLevelSkipNestedVolumeSetting" = $true;
        "nestedVolumeTypesToSkip"              = $null;
        "followNasSymlinkTarget"               = $false
    }

    if($followNasLinks){
        $newParam.followNasSymlinkTarget = $True
    }

    # get source mount points
    $source = $sources.nodes | Where-Object {$_.protectionSource.id -eq $sourceId}
    if($newServer -or $allServers){
        "  processing $($source.protectionSource.name)"
    }
    $mountPoints = $source.protectionSource.physicalProtectionSource.volumes.mountPoints | Where-Object {$_ -ne $null -and $_ -ne ''}

    $includePathsToProcess = @()
    $excludePathsToProcess = @()

    # get new include / exclude paths to process
    if($newServer -or $allServers){
        $includePathsToProcess = @($includePaths | Where-Object {$_ -ne $null -and $_ -ne ''})
        $excludePathsToProcess = @($excludePaths | Where-Object {$_ -ne $null -and $_ -ne ''})
    }

    # get existing include / exclude paths
    $theseParams = $existingParams | Where-Object {$_.id -eq $sourceId}
    if($theseParams){
        if(($newServer -and (! $replaceRules)) -or
           ((! $newServer) -and (! ($replaceRules -and $allServers)))){
               $excludePathsToProcess += $theseParams.filePaths.excludedPaths
               $includePathsToProcess += $theseParams.filePaths.includedPath
               $newParam.followNasSymlinkTarget = $theseParams.followNasSymlinkTarget
               $newParam.usesPathLevelSkipNestedVolumeSetting = $theseParams.usesPathLevelSkipNestedVolumeSetting
               $newParam.nestedVolumeTypesToSkip = $theseParams.nestedVolumeTypesToSkip
        }
    }

    # process exclude paths
    $excludePathsProcessed = @()
    $wildCardExcludePaths = $excludePathsToProcess | Where-Object {$_ -ne $null -and $_.subString(0,2) -eq '*:'}
    $excludePathsToProcess = $excludePathsToProcess | Where-Object {$_ -notin $wildCardExcludePaths}
    foreach($wildCardExcludePath in $wildCardExcludePaths){
        foreach($mountPoint in $mountPoints){
            $excludePathsToProcess += "$($mountPoint):" + $wildCardExcludePath.subString(2)
        }
    }
    foreach($excludePath in $excludePathsToProcess){
       if($null -ne $excludePath -and $excludePath.subString(1,1) -eq ':'){
            $excludePath = "/$($excludePath.replace(':','').replace('\','/'))".replace('//','/')
       }
       if($null -ne $excludePath -and $excludePath -notin $excludePathsProcessed){
        $excludePathsProcessed += $excludePath
       }
    }
    # process include paths
    $includePathsProcessed = @()
    
    if($allDrives -or '$ALL_LOCAL_DRIVES' -in $includePathsToProcess){
        if($cluster.clusterSoftwareVersion -gt '6.5.1b'){
            $includePathsProcessed += '$ALL_LOCAL_DRIVES'
        }else{
            foreach($mountPoint in $mountPoints){
                $includePathsProcessed += "/$($mountPoint.replace(':','').replace('\','/'))/".replace('//','/')
            }
        }
    }else{
        foreach($includePath in $includePathsToProcess){
            foreach($mountPoint in $mountPoints){
                if(($includePath.split('\')[0] -eq $mountPoint.split('\')[0]) -or ($includePath.split('/')[1] -eq $mountPoint.split(':')[0])){
                    $includePathsProcessed = @($includePathsProcessed) + ,"/$($includePath.replace(':','').replace('\','/'))".replace('//','/')
                }
            }
        }
    }
    foreach($includePath in $includePathsProcessed | Sort-Object -Unique){
        $newFilePath= @{
            "includedPath" = $includePath;
            "skipNestedVolumes" = $skip;
            "excludedPaths" = @()
        }
        foreach($excludePath in $excludePathsProcessed){
            if($excludePath -match $includePath -or $includePath -eq '$ALL_LOCAL_DRIVES' -or $excludePath[0] -ne '/'){
                $newFilePath.excludedPaths += ,$excludePath
            }
        }
        $newParam.filePaths += ,$newFilePath
    }
    if($newServer -or $allServers){
        $newParams += $newParam
    }else{
        $newParams += $theseParams
    }
}

# update job
$job.physicalParams.fileProtectionTypeParams.objects = $newParams
$null = api put -v2 "data-protect/protection-groups/$($job.id)" $job

