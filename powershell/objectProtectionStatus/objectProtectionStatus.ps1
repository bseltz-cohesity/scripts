### usage: ./objectProtectionDetails.ps1 -vip mycluster `
#                                        -username myusername `
#                                        -domain mydomain.net `
#                                        -object myserver.mydomain.net `
#                                        -dbname mydatabase

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$object,
    [Parameter()][string]$dbname
)

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

### authenticate
apiauth -vip $vip -username $username -domain $domain -quiet

# get protection jobs
$jobs = api get "protectionJobs?includeLastRunAndStats=true" | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false}

# get root protection sources
$sources = api get protectionSources
$sqlSources = api get protectionSources?environments=kSQL
$oracleSources = api get protectionSources?environments=kOracle

$jobReports = @()

# get object ID
$objectId = getObjectId $object

if($null -eq $objectId){
    Write-Host "None::Not Found" -ForegroundColor Yellow
    exit 1
}else{
    # find protection jobs that protect object
    $objectJobIDs = @()
    foreach($job in $jobs){
        $environment = $job.environment
        $parentId = $job.parentSourceId
        $sourceIds = $job.sourceIds
        if( $environment -ne 'kOracle' -and $environment -ne 'kSQL'){
            $protectedObjects = api get "protectionSources/protectedObjects?environment=$environment&id=$parentId" |
                Where-Object {$_.protectionSource.id -eq $objectId}
            foreach($protectedObject in $protectedObjects){
                foreach($protectionJob in $protectedObject.protectionJobs){
                    $objectJobIDs += $protectionJob.id | Sort-Object -Unique
                }
            }
        }else{
            foreach($sourceId in $sourceIds){
                $protectedObjects = api get "protectionSources/protectedObjects?environment=$environment&id=$sourceId" |
                    Where-Object {$_.protectionSource.parentId -eq $objectId}
                foreach($protectedObject in $protectedObjects){
                    foreach($protectionJob in $protectedObject.protectionJobs){
                        $objectJobIDs += $protectionJob.id | Sort-Object -Unique
                    }
                }
            }
        } 
    }

    if($objectJobIDs.Count -eq 0){
        Write-Host "None::Not Protected" -ForegroundColor Yellow
        exit 1
    }else{
        foreach($job in $jobs | Where-Object id -in $objectJobIDs){
            
            $jobName = $job.name
            $jobList += $jobName
            $jobType = $job.environment.substring(1)
            $jobReport = @{'jobName' = $jobName; 'jobType' = $jobType; 'dbList' = @(); 'objectStatus' = 'Protected'; 'objectLastRun' = 0}

            # get list of protected SQL DBs for this object
            if($job.environment -eq 'kSQL' -or $job.environment -eq 'kOracle'){
                if($job.environment -eq 'kSQL'){
                    $dbList = $sqlSources.nodes.applicationNodes.nodes | Where-Object {$_.protectionSource.parentId -eq $objectId}
                    $protectedDbList = api get "protectionSources/protectedObjects?environment=kSQL&id=$objectId"
                }else{
                    $dbList = $oracleSources.nodes.applicationNodes | Where-Object {$_.protectionSource.parentId -eq $objectId}
                    $protectedDbList = api get "protectionSources/protectedObjects?environment=kOracle&id=$objectId"
                }
                foreach($db in $dbList){
                
                    if($db.protectionSource.id -in $protectedDbList.protectionSource.id){
                        # db is protected by some job
                        $protectedDb = $protectedDbList | Where-Object {$_.protectionSource.id -eq $db.protectionSource.id}
                        if($jobName -in $protectedDb.protectionJobs.name){
                            # protected by this job
                            $jobReport.dbList += @{'name' = $db.protectionSource.name; 'shortname' = $db.protectionSource.name.split('/')[-1]; 'status' = 'Protected'; 'lastrun' = 'None'}
                        }else{
                            # protected by another job
                            $jobReport.dbList += @{'name' = $db.protectionSource.name; 'shortname' = $db.protectionSource.name.split('/')[-1]; 'status' = 'Protected - Other Job'; 'lastrun' = 'None'}
                        }
                    }else{
                        # db is not protected
                        $jobReport.dbList += @{'name' = $db.protectionSource.name; 'shortname' = $db.protectionSource.name.split('/')[-1]; 'status' = 'Not Protected'; 'lastrun' = 'None'}
                    }
                }
            }

            $24HoursAgo = dateToUsecs ((Get-Date).AddDays(-1))
            
            # find latest recovery points
            $search = api get "/searchvms?entityTypes=kSQL&showAll=false&entityTypes=kOracle&onlyLatestVersion=true&vmName=$object"
            $searchResults = $search.vms | Where-Object {$_.vmDocument.jobName -eq $jobName}
            foreach($db in $jobReport.dbList){
                if($db.status -ne 'Not Protected' -and $db.status -ne 'Protected - Other Job'){
                    $searchResult = $searchResults | Where-Object {$_.vmDocument.objectName -eq $db.name}
                    if($searchResult){
                        $db.status = 'Success'
                        $db.lastrun = $searchResult.vmDocument.versions[0].instanceId.jobStartTimeUsecs
                        if($db.lastrun -gt $jobReport.objectLastRun){
                            $jobReport.objectLastRun = $db.lastrun
                            $jobReport.objectStatus = 'Success'
                        }
                    }
                }
            }

            # get runs last 24 hours
            $runs = api get "protectionRuns?jobId=$($job.id)&excludeTasks=true&startTimeUsecs=$24HoursAgo"
            foreach($run in $runs | Sort-Object -Property {$_.backupRun.stats.startTimeUsecs}){
                $runStart = $run.backupRun.stats.startTimeUsecs
                $thisRun = api get "/backupjobruns?id=$($job.id)&exactMatchStartTimeUsecs=$($runStart)"
                # still running?
                if($thisRun.backupJobRuns.protectionRuns[0].backupRun.PSObject.Properties['activeAttempt']){
                    foreach($attempt in $thisRun.backupJobRuns.protectionRuns[0].backupRun.activeAttempt){
                        foreach($source in $attempt.sources){
                            if($source.id -eq $objectId){
                                if($jobReport.objectStatus -ne 'Success'){
                                    $jobReport.objectStatus = 'Running'
                                    $jobReport.objectLastRun = $runStart
                                }
                            }
                        }
                        foreach($app in $attempt.appEntityStateVec){
                            $db = $jobReport.dbList | Where-Object {$_.name -eq $app.appEntity.displayName}
                            if($db){
                                if($db.status -ne 'Success'){
                                    $db.lastrun = $runStart
                                    $db.status = 'Running'
                                }
                            }
                        }
                    }
                }
                # completed run
                if($thisRun.backupJobRuns.protectionRuns[0].backupRun.PSObject.Properties['latestFinishedTasks']){
                    foreach($task in $thisRun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks | Sort-Object -Property {$_.base.sources[0].source.displayName}){
                        if($task.base.sources[0].source.id -eq $objectId){
                            $jobReport.objectStatus = $task.base.publicStatus.subString(1)
                            $jobReport.objectLastRun = $runStart
                        }
                        foreach($app in $task.appEntityStateVec){
                            $db = $jobReport.dbList | Where-Object {$_.name -eq $app.appEntity.displayName}
                            if($db){
                                $db.lastrun = $runStart
                                $db.status = $app.publicStatus.subString(1)
                            }
                        }
                    }
                }
            }
            $jobReports += $jobReport
        }
    }
    $dbReported = $false
    foreach($jobReport in $jobReports){
        
        if((! $dbname) -or ($dbname -in $jobReport.dbList.shortname) -or ($dbname -in $jobReport.dbList.name)){
            Write-Host ("`n    Job Name: {0} ({1})" -f $jobReport.jobName, $jobReport.jobType)
            Write-Host (" Object Name: {0} ({1})" -f $object, $jobReport.objectStatus)
            if($jobReport.objectLastRun -ne 0){
                Write-Host ("  Latest Run: {0}" -f (usecsToDate $jobReport.objectLastRun))
            }else{
                Write-Host ("  Latest Run: (No Run Yet)")
            }
            
            foreach($db in $jobReport.dbList){
                if(! $dbname -or ($db.name -eq $dbname) -or ($db.name.split('/')[-1] -eq $dbname)){
                    Write-Host ("     DB Name: {0} ({1})" -f $db.name, $db.status)
                    $dbReported = $True
                }
            }
        }
    }
    if($dbname -and ! $dbReported){
        Write-Host ("{0} Not Found on {1}" -f $dbname, $object) -ForegroundColor Yellow
    }
}
write-host ""
exit 0
