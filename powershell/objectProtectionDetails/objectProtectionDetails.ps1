### usage: ./objectProtectionDetails.ps1 -vip mycluster -username myusername -domain mydomain.net -objects vm1, vm2 [ -startDate 2019-10-01 ] [ -endDate 2019-11-01 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][array]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True, ValueFromPipeline)][string[]]$objects,
    [Parameter()][string]$startDate = (Get-Date).AddMonths(-1),
    [Parameter()][string]$endDate = (get-date)
)

function getObjectId($objectName){
    $global:_object_id = $null

    function get_nodes($obj){

        if($obj.protectionSource.name -eq $objectName){
            $global:_object_id = $obj.protectionSource.id
            $global:object = $obj.protectionSource.name
            break
        }
        if($obj.name -eq $objectName){
            $global:_object_id = $obj.id
            $global:object = $obj.name
            break
        }        
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object_id){
                    get_nodes $node
                }
            }
        }
        if($obj.PSObject.Properties['applicationNodes']){
            foreach($node in $obj.applicationNodes){
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

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$foundObject = @{}
$objectProtected = @{}

foreach($v in $vip){
    ### authenticate
    apiauth -vip $v -username $username -domain $domain -quiet

    $cluster = api get cluster

    # get protection jobs
    $jobs = api get protectionJobs

    # get root protection sources
    $sources = api get protectionSources

    foreach($object in $objects){
        # get object ID
        $objectId = getObjectId $object

        if($null -ne $objectId){
            $foundObject[$object] = $True
            # find protection job
            $objectJobs = $jobs | Where-Object {
                $objectId -in $_.sourceIds -or
                $objectId -in $_.sourceSpecialParameters.oracleSpecialParameters.applicationEntityIds -or
                $objectId -in $_.sourceSpecialParameters.sqlSpecialParameters.applicationEntityIds
            }
            if($null -ne $objectJobs){
                $objectProtected[$object] = $True
                foreach($job in $objectJobs){
                    "`n$($cluster.name): $global:object ($($job.name))`n"
                    "Start Time          End Time            Type         Object   Read       Logical Size"
                    "------------------  ------------------  -----------  -------  ---------  ------------"
                    # get protectionRuns
                    $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$(dateToUsecs $startDate)&endTimeUsecs=$(dateToUsecs $endDate)&numRuns=999999" | Where-Object { $_.backupRun.snapshotsDeleted -eq $false}
                    foreach($run in $runs){
                        # runs stats
                        $runStart = $run.backupRun.stats.startTimeUsecs
                        $runEnd = $run.backupRun.stats.endTimeUsecs
                        $runType = $run.backupRun.runType.substring(1).replace('Regular','Incremental')
                        $objLogical = ''
                        $objLogicalUnits = ''
                        $objRead = ''
                        $objReadUnits = ''
                        $objStatus = ''
                        $objStart = (usecsToDate $runStart).ToString("MM/dd/yyyy hh:mmtt")
                        $objEnd = (usecsToDate $runEnd).ToString("MM/dd/yyyy hh:mmtt")
                        if($run.backupRun.PSObject.Properties['sourceBackupStatus']){
                            # object stats
                            foreach($source in $run.backupRun.sourceBackupStatus){
                                if($source.source.name -eq $object){
                                    $objStatus = $source.status.subString(1)
                                    if($source.PSObject.Properties['warnings']){
                                        $objStatus = 'Warning'
                                    }
                                    $objLogical = $source.stats.totalLogicalBackupSizeBytes
                                    $objLogicalUnits = 'B'
                                    $objRead = $source.stats.totalBytesReadFromSource
                                    $objReadUnits = 'B'
                                    if($objLogical -ge 1073741824){
                                        $objLogical = [math]::round(($objLogical/1073741824),1)
                                        $objLogicalUnits = 'GiB'
                                    }elseif ($objLogical -ge 1048576) {
                                        $objLogical = [math]::round(($objLogical/1048576),1)
                                        $objLogicalUnits = 'MiB'                                                              
                                    }elseif ($objLogical -ge 1024) {
                                        $objLogical = [math]::round(($objLogical/1024),1)
                                        $objLogicalUnits = 'KiB'                                                              
                                    }
                                    if($objRead -ge 1073741824){
                                        $objRead = [math]::round(($objRead/1073741824),1)
                                        $objReadUnits = 'GiB'
                                    }elseif ($objRead -ge 1048576) {
                                        $objRead = [math]::round(($objRead/1048576),1)
                                        $objReadUnits = 'MiB'                                                              
                                    }elseif ($objRead -ge 1024) {
                                        $objRead = [math]::round(($objRead/1024),1)
                                        $objReadUnits = 'KiB'                                                              
                                    }
                                    $objStart = (usecsToDate $source.stats.startTimeUsecs).ToString("MM/dd/yyyy hh:mmtt")
                                    $objEnd = (usecsToDate $source.stats.endTimeUsecs).ToString("MM/dd/yyyy hh:mmtt")
                                    "{0,-19} {1,-19} {2,-12} {3,-8} {4,5} {5,-4} {6} {7,2}" -f $objStart, $objEnd, $runType, $objStatus, $objRead, $objReadUnits, $objLogical, $objLogicalUnits
                                }
                            }
                        }
                    }
                }
            }
        }    
    }
}

foreach($object in $objects){
    if($object -notin $foundObject.Keys){
        Write-Host "$object not found" -foregroundcolor Yellow
    }elseif($object -notin $objectProtected.Keys){
        Write-Host "$object not protected" -foregroundcolor Yellow
    }
}
