# usage: ./addPhysicalToProtectionJob.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',    # local or AD domain
    [Parameter()][array]$servers,              # optional names of servers to protect (comma separated)
    [Parameter()][string]$serverList = '',     # optional textfile of servers to protect
    [Parameter()][array]$inclusions,           # optional paths to exclude (comma separated)
    [Parameter()][string]$inclusionList = '',  # optional list of exclusions in file
    [Parameter()][array]$exclusions,           # optional paths to exclude (comma separated)
    [Parameter()][string]$exclusionList = '',  # optional list of exclusions in file
    [Parameter(Mandatory = $True)][string]$jobName    # name of the job to add server to
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
        Write-Host "Server list $serverList not found!" -ForegroundColor Yellow
        exit 1
    }
}
if($serversToAdd.Count -eq 0){
    Write-Host "No servers specified" -ForegroundColor Yellow
    exit 1
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
        Write-Host "Inclusions file $inclusionList not found!" -ForegroundColor Yellow
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
        Write-Host "Exclusions file $exclusionList not found!" -ForegroundColor Yellow
        exit 1
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get the protectionJob
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&environments=kPhysical"
$job = $jobs.protectionGroups | Where-Object {$_.name -ieq $jobName -and $_.physicalParams.protectionType -eq 'kVolume'}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit 1
}

# get physical protection sources
$sources = api get protectionSources?environment=kPhysical

foreach($server in $serversToAdd){
    $node = $sources.nodes | Where-Object { $_.protectionSource.name -eq $server }
    if($node){
        # new object
        $job.physicalParams.volumeProtectionTypeParams.objects = @($job.physicalParams.volumeProtectionTypeParams.objects | Where-Object {$_.id -ne $node.protectionSource.id})
        $newObject = @{
            'id' = $node.protectionSource.id;
            'name' = $node.protectionSource.name;
            'volumeGuids' = $null
        }
        if($includePaths.Count -gt 0 -or $excludePaths.Count -gt 0){

            # add included volumes
            $newObject.volumeGuids = @()
            if($includePaths.Count -gt 0){
                foreach($includePath in $includePaths){
                    $volume = $node.protectionSource.physicalProtectionSource.volumes | Where-Object {$includePath -in $_.mountPoints -or $includePath -eq $_.label}
                    if($volume){
                        $newObject.volumeGuids += ,$volume.guid
                    }
                }
            }
            
            # remove excluded volumes
            if($excludePaths.Count -gt 0){
                if($includePaths.Count -eq 0){
                    foreach($volume in $node.protectionSource.physicalProtectionSource.volumes){
                        $newObject.volumeGuids += $volume.guid
                    }
                }
                foreach($excludePath in $excludePaths){
                    $excludeVolume = $node.protectionSource.physicalProtectionSource.volumes | Where-Object {$excludePath -in $_.mountPoints -or $excludePath -eq $_.label}
                    if($excludeVolume){
                        $newObject.volumeGuids = @($newObject.volumeGuids | Where-Object {$_ -ne $excludeVolume.guid})
                    }
                }
            }
        }
        if($null -eq $newObject.volumeGuids -or $newObject.volumeGuids.Count -gt 0){
            write-host "adding $server to $jobName..."
            $job.physicalParams.volumeProtectionTypeParams.objects += ,$newObject
        }else{
            Write-Host "No volumes selected for $server" -ForegroundColor Yellow
        }
    }else{
        Write-Host "$server is not a registered source" -ForegroundColor Yellow
    }
}

# update job
if($job.physicalParams.volumeProtectionTypeParams.objects.Count -gt 0){
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}

