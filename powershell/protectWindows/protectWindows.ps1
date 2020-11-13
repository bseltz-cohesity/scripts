# usage: ./protectWindows.ps1 -vip mycluster `
#                             -username myusername `
#                             -domain mydomain.net `
#                             -servers server1.mydomain.net, server2.mydomain.net `
#                             -jobName 'File-based Windows Job' `
#                             -exclusions 'c:\windows', 'e:\excluded', 'c:\temp' `
#                             -serverList .\serverlist.txt `
#                             -exclusionList .\exclusions.txt `
#                             -allDrives `
#                             -skipNestedMountPoints

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
    [Parameter()][switch]$overwriteAll,
    [Parameter()][switch]$allDrives
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
            $excludePaths += $exclusion
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

# get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
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
        if($node.protectionSource.physicalProtectionSource.hostType -eq 'kWindows'){
            $sourceId = $node.protectionSource.id
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

$existingParams = $job.sourceSpecialParameters
$newParams = @()
foreach($sourceId in $sourceIds){
    if($sourceId -in $newSourceIds -or $overwriteAll){
        $newParam= @{
            "sourceId" = $sourceId;
            "physicalSpecialParameters" = @{
                "filePaths" = @()
            }
        }
        $source = $sources.nodes | Where-Object {$_.protectionSource.id -eq $sourceId}
        "  processing $($source.protectionSource.name)"
    
        if($allDrives){
            $mountPoints = $source.protectionSource.physicalProtectionSource.volumes.mountPoints
            foreach ($mountPoint in $mountPoints | Where-Object {$_ -ne $null -and $_ -ne ''}) {
                $includePaths += $mountPoint
            }
        }
        foreach($includePath in $includePaths | Where-Object {$_ -ne $null -and $_ -ne ''}){
            $backupFilePath = "/$includePath".Replace(':\','/')
            $mountLetter = $backupFilePath.Substring(1,1).ToUpper()
            $filePath = @{
                "backupFilePath" = $backupFilePath;
                "skipNestedVolumes" = $skip;
                "excludedFilePaths" = @()
            }
            $excludedFilePaths = @()
            foreach ($exclusion in $excludePaths | Where-Object {$_ -ne ''}) {
                $exclusion = $exclusion.ToString()
                $thisExclusion = "/$($exclusion.replace(':','').replace('\','/'))"
                # handle wildcard drive letter
                if($thisExclusion.Substring(0,3) -eq '/*/'){
                    $thisExclusion = "/$mountLetter/$($thisExclusion.Substring(3))"
                }
                # handle wildcard file name
                if("$thisExclusion" -match "\*"){
                    $thisExclusion = $thisExclusion.Substring(1)
                }
                # add to exclusions if drive letter match (or wildcard file)
                if("$thisExclusion" -match "$backupFilePath" -or "$thisExclusion" -match "\*"){
                    $excludedFilePaths += $thisExclusion
                }
            }
            if($excludedFilePaths.Length -gt 0){            
                $filePath.excludedFilePaths = @($filePath.excludedFilePaths + $excludedFilePaths | Select-Object -Unique)
            }
            if($includePath -notin $exclusions){
                $newParam.physicalSpecialParameters.filePaths += $filePath
            }
        }
        $newParams += $newParam
    }else{
        $newParams += $existingParams | Where-Object {$_.sourceId -eq $sourceId}
    }
}
# update job
$job.sourceSpecialParameters = $newParams
$job.sourceIds = @($sourceIds)
$null = api put "protectionJobs/$($job.id)" $job
