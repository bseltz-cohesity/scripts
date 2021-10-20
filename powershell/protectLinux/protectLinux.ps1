# usage: ./protectPhysicalLinux.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt -exclusionList ./exclusions.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][array]$servers = '',  # optional name of one server protect
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter()][array]$inclusions = '', # optional paths to exclude (comma separated)
    [Parameter()][string]$inclusionList = '',  # optional list of exclusions in file
    [Parameter()][array]$exclusions = '',  # optional name of one server protect
    [Parameter()][string]$exclusionList = '',  # required list of exclusions
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add server to
    [Parameter()][switch]$skipNestedMountPoints,  # 6.3 and below - skip all nested mount points
    [Parameter()][array]$skipNestedMountPointTypes = @(),  # 6.4 and above - skip listed mount point types
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
            $serversToAdd += $server
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
            $includePaths += $inclusion
        }
    }else{
        Write-Warning "Inclusions file $inclusionList not found!"
        exit
    }
}
if(! $includePaths){
    $includePaths += '/'
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
            $excludePaths += $exclusion
        }
    }else{
        Write-Warning "Exclusions file $exclusionList not found!"
        exit
    }
}

# skip nested mount points
if($skipNestedMountPoints){
    $skip = $True
}else{
    $skip = $false
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

$cluster = api get cluster

if($cluster.clusterSoftwareVersion -gt '6.5'){
    $protectionGroups = api get "data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true" -v2
    $protectionGroup = $protectionGroups.protectionGroups | Where-Object name -eq $jobName
    $globalExcludePaths = $protectionGroup.physicalParams.fileProtectionTypeParams.globalExcludePaths
}

# get physical protection sources
$sources = api get protectionSources?environment=kPhysical

# add sourceIds for new servers
$sourceIds = @($job.sourceIds)
$newSourceIds = @()
foreach($server in $serversToAdd | Where-Object {$_ -ne ''}){
    $server = $server.ToString()
    $node = $sources.nodes | Where-Object { $_.protectionSource.name -eq $server }
    if($node){
        if($node.registrationInfo.refreshErrorMessage){
            Write-Warning "$server has source registration errors"
        }else{
            if($node.protectionSource.physicalProtectionSource.hostType -ne 'kWindows'){
                $sourceId = $node.protectionSource.id
                $sourceIds += $sourceId
                $newSourceIds += $sourceId
            }else{
                Write-Warning "$server is not a Linux/AIX/Solaris host"
            }
        }
    }else{
        Write-Warning "$server is not a registered source"
    }
}

$sourceIds = @($sourceIds | Select-Object -Unique)
$existingParams = $job.sourceSpecialParameters
$newParams = @()

# process inclusions and exclusions
foreach($sourceId in $sourceIds){
    $source = $sources.nodes | Where-Object {$_.protectionSource.id -eq $sourceId}
    $newServer = $sourceId -in $newSourceIds

    $theseParams = $existingParams | Where-Object {$_.sourceId -eq $sourceId}

    if($newServer){
        $newParam = @{
            "sourceId" = $sourceId;
            "physicalSpecialParameters" = @{
                "filePaths" = @()
            }
        }
    }else{
        $newParam = $theseParams
    }


    $includePathsToProcess = @()
    $excludePathsToProcess = @()

    # get existing rules
    
    if($theseParams){
        if(($newServer -and (! $replaceRules)) -or
            ((! $newServer) -and (! ($replaceRules -and $allServers)))){
                $excludePathsToProcess += $theseParams.physicalSpecialParameters.filePaths.excludedFilePaths
                $includePathsToProcess += $theseParams.physicalSpecialParameters.filePaths.backupFilePath
        }
    }

    # add new rules
    if($newServer -or $allServers){
        "  processing $($source.protectionSource.name)"
        $includePathsToProcess += @($includePaths | Where-Object {$_ -ne $null -and $_ -ne ''})
        $excludePathsToProcess += @($excludePaths | Where-Object {$_ -ne $null -and $_ -ne ''})
        if($skipNestedMountPointTypes.Count -gt 0){
            $newParam.physicalSpecialParameters['usesSkipNestedVolumesVec'] = $True
            $newParam.physicalSpecialParameters['skipNestedVolumesVec'] = $skipNestedMountPointTypes
        }
    }

    # process include rules
    foreach($includePath in $includePathsToProcess | Where-Object {$_ -ne ''} | Sort-Object -Unique){
        $includePath = $includePath.ToString()
        $filePath = @{
            "backupFilePath" = $includePath;
            "skipNestedVolumes" = $skip;
            "excludedFilePaths" = @()
        }
        $newParam.physicalSpecialParameters.filePaths = @($newParam.physicalSpecialParameters.filePaths | Where-Object backupFilePath -ne $includePath)
        $newParam.physicalSpecialParameters.filePaths += $filePath
    }

    # process exclude rules
    foreach($excludePath in $excludePathsToProcess | Where-Object {$_ -and $_ -ne ''} | Sort-Object -Unique){
        $excludePath = $excludePath.ToString()
        $parentPath = $newParam.physicalSpecialParameters.filePaths | Where-Object {$excludePath.contains($_.backupFilePath)} | Sort-Object -Property {$_.backupFilePath.Length} -Descending | Select-Object -First 1
        if($parentPath){
            $parentPath.excludedFilePaths += $excludePath
        }else{
            foreach($parentPath in $newParam.physicalSpecialParameters.filePaths){
                $parentPath.excludedFilePaths += $excludePath
            }
        }
    }
    $newParams += $newParam
}

$newParams | ConvertTo-Json -Depth 99 | Out-File -FilePath protectLinuxDebug.txt

# update job
$job.sourceSpecialParameters = $newParams
$job.sourceIds = @($sourceIds)

$null = api put "protectionJobs/$($job.id)" $job

if($cluster.clusterSoftwareVersion -gt '6.5'){
    if($globalExcludePaths){
        $protectionGroups = api get "data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true" -v2
        $protectionGroup = $protectionGroups.protectionGroups | Where-Object name -eq $jobName
        setApiProperty -object $protectionGroup.physicalParams.fileProtectionTypeParams -name 'globalExcludePaths' -value $globalExcludePaths
        $null = api put "data-protect/protection-groups/$($protectionGroup.id)" $protectionGroup -v2
    }
}
