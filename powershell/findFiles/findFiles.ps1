### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][array]$searchString,
    [Parameter()][string]$objectName,
    [Parameter()][string]$objectType,
    [Parameter()][string]$jobName,
    [Parameter()][switch]$extensionOnly,
    [Parameter()][switch]$localOnly,
    [Parameter()][switch]$getMtime,
    [Parameter()][int]$throttle = 0,
    [Parameter()][int]$pageSize = 1000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$rootNodes = api get protectionSources?rootNodes
$sources = api get protectionSources
$jobs = api get protectionJobs
$cluster = api get cluster

function getObjectId($objectName){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            $global:_object_id = $obj.protectionSource.id
            break
        }
        if($obj.name -eq $objectName){
            $global:_object_id = $obj.id
            break
        }        
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object_id){
                    get_nodes $node
                }
            }
        }
    }
    
    foreach($source in $sources){
        if($null -eq $global:_object_id){
            get_nodes $source
        }
    }
    return $global:_object_id
}

function getResults($thisQuery, $thisString=$null){
    $results = api get "restore/files?paginate=true&pageSize=$($pageSize)$($thisQuery)"

    $oldcookie = $null
    while($True){
        if($results.files.count -gt 0){
            $output = $results.files | where-object { $_.isFolder -ne $True } | Sort-Object -Property {$_.protectionSource.name}, {$_.filename}
            if($extensionOnly -and $thisString){
                $output = $output | Where-Object {$_.fileName -match $thisString+'$'}
            }
            foreach($result in $output){
                if($result.type -ne 'kDirectory' -and $result.type -ne 'kSymLink'){
                    $objectName = $result.protectionSource.name
                    $fileName = $result.filename
                    $parentName = ''
                    $parentId = $result.protectionSource.parentId
                    $jobId = $result.jobUid.id
                    $clusterId = $result.jobUid.clusterId
                    if(!$localOnly -or $clusterId -eq $cluster.id){
                        $clusterIncarnationId = $result.jobUid.clusterIncarnationId
                        $sourceId = $result.protectionSource.id
                        $jobName = ($jobs | Where-Object id -eq $jobId).name
                        if($parentId){
                            $parent = $rootNodes | Where-Object {$_.protectionSource.id -eq $parentId}
                            if($parent){
                                $parentName = $parent.protectionSource.name
                            }
                        }
                        if($getMtime){
                            $mtime = ''
                            $thisFileName = [System.Web.HttpUtility]::UrlEncode($result.fileName)  # [System.Web.HttpUtility]::UrlEncode($result.fileName).Replace('%2f%2f','%2F')
                            $snapshots = api get -v2 "data-protect/objects/$sourceId/protection-groups/$clusterId`:$clusterIncarnationId`:$jobId/indexed-objects/snapshots?indexedObjectName=$thisFileName&includeIndexedSnapshotsOnly=true"
                            if($snapshots.snapshots.Count -gt 0){
                                $snapshots.snapshots[0] | ConvertTo-Json -Depth 99
                                $mtimeUsecs = $snapshots.snapshots[0].lastModifiedTimeUsecs
                                if($mtimeUsecs){
                                    $mtime = usecsToDate $mtimeUsecs
                                }
                            }
                        } 
                        write-host ("{0},{1},{2},{3}" -f $parentName, $objectName, $fileName, $mtime)
                        "{0}`t{1}`t{2}`t{3}`t{4}" -f $jobName, $parentName, $objectName, $fileName, $mtime | Out-File -FilePath foundFiles.tsv -Append
                        $script:fileCount += 1
                    }
                }           
            }
        }else{
            break
        }
        if($results.paginationCookie){
            if($throttle -gt 0){
                Start-Sleep $throttle
            }
            $oldcookie = $results.paginationCookie
            while($results.paginationCookie -eq $oldcookie -and $results){
                $results = api get "restore/files?paginate=true&pageSize=$pageSize&paginationCookie=$($results.paginationCookie)$($thisQuery)"
                if(! $results){
                    "retrying..."
                    Start-Sleep 2
                }
            }
        }else{
            break
        }
    }
}

"JobName`tParent`tObject`tPath`tLast Modified" | Out-File -FilePath foundFiles.tsv

$query = ""
if($objectType){
    $query = $query + "&environments=$objectType"
}
if($jobName){
    $job = $jobs | Where-Object name -eq $jobName
    if(!$job){
        Write-Host "Job $jobName not found" -ForegroundColor Yellow
        exit 1
    }
    $query = $query + "&jobIds=$($job[0].id)"
}
if($objectName){
    $sourceId = getObjectId $objectName
    if(!$sourceId){
        Write-Host "Object $objectName not found" -ForegroundColor Yellow
        exit 1
    }
    $query = $query + "&sourceIds=$($sourceId)"
}

$fileCount = 0

if($searchString.Count -eq 0){
    getResults $query
}else{
    foreach($thisSearchString in $searchString){
        $thisQuery = $query + "&search=$($thisSearchString)"
        getResults $thisQuery $thisSearchString
    }
}

"`n$fileCount indexed files found"

"`nsaving results to foundFiles.tsv"
