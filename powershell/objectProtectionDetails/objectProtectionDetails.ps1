### usage: ./objectProtectionDetails.ps1 -vip mycluster -username myusername -domain mydomain.net -objects vm1, vm2 [ -includeExpired ] [ -startDate 2019-10-01 ] [ -endDate 2019-11-01 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True, ValueFromPipeline)][string[]]$objects,
    [Parameter()][string]$startDate = (Get-Date).AddMonths(-1),
    [Parameter()][string]$endDate = (get-date),
    [Parameter()][switch]$includeExpired
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
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain -quiet

# get protection jobs
$jobs = api get protectionJobs

# get root protection sources
$sources = api get protectionSources

foreach($object in $objects){
    # get object ID
    $objectId = getObjectId $object

    if($null -eq $objectId){
        Write-Host "`n$object not found" -ForegroundColor Yellow
    }else{
        # find protection job
        $jobs = $jobs | Where-Object {
            $objectId -in $_.sourceIds -or
            $objectId -in $_.sourceSpecialParameters.oracleSpecialParameters.applicationEntityIds -or
            $objectId -in $_.sourceSpecialParameters.sqlSpecialParameters.applicationEntityIds
        }
        if($null -eq $jobs){
            Write-Host "`n$object not protected" -ForegroundColor Yellow
            exit
        }else{
            foreach($job in $jobs){
                "`n$global:object ($($job.name))`n"
                "Start Time          End Time            Job Run  Type         Object   Read       Logical Size"
                "------------------  ------------------  -------  -----------  -------  ---------  ------------"
                # get protectionRuns
                $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$(dateToUsecs $startDate)&endTimeUsecs=$(dateToUsecs $endDate)&numRuns=999999"
                if($includeDeleted -eq $false){
                    $runs = $runs | Where-Object { $_.backupRun.snapshotsDeleted -eq $false}
                }
                foreach($run in $runs){
                    # runs stats
                    $runStart = $run.backupRun.stats.startTimeUsecs
                    $runEnd = $run.backupRun.stats.endTimeUsecs
                    $runStatus = $run.backupRun.status.subString(1)
                    $runType = $run.backupRun.runType.substring(1).replace('Regular','Incremental')
                    $objLogical = ''
                    $objLogicalUnits = ''
                    $objRead = ''
                    $objReadUnits = ''
                    $objStatus = ''
                    $objStart = (usecsToDate $runStart).ToString("MM/dd/yyyy hh:mmtt")
                    $objEnd = (usecsToDate $runEnd).ToString("MM/dd/yyyy hh:mmtt")
                    if($run.backupRun.PSObject.Properties['warnings']){
                        $runStatus = 'Warning'
                    }
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
                            }
                        }
                    }
                    
                    "{0,-19} {1,-19} {2,-8} {3,-12} {4,-8} {5,5} {6,-4} {7} {8,2}" -f $objStart, $objEnd, $runStatus, $runType, $objStatus, $objRead, $objReadUnits, $objLogical, $objLogicalUnits
                }
            }
        }
    }    
}