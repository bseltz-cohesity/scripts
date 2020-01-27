# usage: ./protectWindows.ps1 -vip mycluster `
#                             -username myusername `
#                             -domain mydomain.net
#                             -servers server1.mydomain.net, server2.mydomain.net
#                             -jobName 'File-based Windows Job' 
#                             -exclusions 'c:\windows', 'e:\excluded', 'c:\temp'
#                             -serverList .\serverlist.txt
#                             -exclusionList .\exclusions.txt
#                             -skipNestedMountPoints

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][array]$servers = '',  # optional names of servers to protect (comma separated)
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter()][array]$exclusions = '', # optional paths to exclude (comma separated)
    [Parameter()][string]$exclusionList = '',  # optional list of exclusions in file
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add server to
    [Parameter()][switch]$skipNestedMountPoints  # if omitted, nested mountpoints will not be skipped
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

foreach($server in $serversToAdd){
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
    if($sourceId -in $newSourceIds){
        $newParam= @{
            "sourceId" = $sourceId;
            "physicalSpecialParameters" = @{
                "filePaths" = @()
            }
        }
        $source = $sources.nodes | Where-Object {$_.protectionSource.id -eq $sourceId}
        "  processing $($source.protectionSource.name)"
    
        # identify existing source volumes
        $mountPoints = $source.protectionSource.physicalProtectionSource.volumes.mountPoints
    
        foreach ($mountPoint in $mountPoints | Where-Object {$_ -ne $null}) {
    
            $backupFilePath = "/$mountPoint".Replace(':\','/')
            $mountLetter = $backupFilePath.Substring(0,$backupFilePath.Length-1)
            $filePath = @{
                "backupFilePath" = $backupFilePath;
                "skipNestedVolumes" = $skip;
                "excludedFilePaths" = @()
            }
    
            # identify exclusions that apply to existing source volumes
            $excludedFilePaths = @()
            foreach ($exclusion in $exclusions) {
                $exclusion = $exclusion.ToString()
                if ($exclusion.substring(0, 3) -eq $mountPoint) {
                    $exclusion = "/$($exclusion.replace(':','').replace('\','/'))"
                    $excludedFilePaths += $exclusion
                }elseif ($exclusion.substring(0, 3) -eq '*:\') {
                    $exclusion = "$($exclusion.replace('*:',$mountLetter).replace('\','/'))"
                    $excludedFilePaths += $exclusion
                }elseif ($exclusion.Contains('*') -or $exclusion.Contains('?')){
                    $exclusion = $exclusion.replace('\','/')
                    $excludedFilePaths += $exclusion
                }
            }
            if($excludedFilePaths.Length -gt 0){            
                $filePath.excludedFilePaths = @($filePath.excludedFilePaths + $excludedFilePaths | Select-Object -Unique)
            }
            if($mountPoint -notin $exclusions){
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
