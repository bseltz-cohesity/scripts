### usage: ./objectProtectionDetails.ps1 -vip mycluster `
#                                        -username myusername `
#                                        -domain mydomain.net `
#                                        -object myserver.mydomain.net `
#                                        -dbname mydatabase

### process commandline arguments
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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][string]$sourceName,
    [Parameter()][string]$object,
    [Parameter()][string]$dbname,
    [Parameter()][switch]$returnData
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$foundObject = $False
$jobs = @()
$jobNames = @()
$objectId = $null
$dbenvironments = @('kSQL', 'kOracle')
$jobReports = @()

if(!$sourceName -and $object){
    $sourceName = $object
}

if(!$object -and $sourceName){
    $object = $sourceName
}

if(!$sourceName -and !$object){
    Write-Host "-sourceName or -object required" -ForegroundColor Yellow
    exit 1
}

Write-Host "Searching for $object"

$sources = api get protectionSources/registrationInfo

$source = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $sourceName}

if(!$source){
    Write-Host "Registered source $sourceName not found" -ForegroundColor Yellow
    exit 1
}

$rootNode = $source[0]

$parentId = $rootNode.rootNode.id
$parentName = $rootNode.rootNode.name
if($sourceName -eq $object){
    $foundObject = $True
    $objectId = $parentId
}

$protectedObjectCache = @{}

function getProtectedObjects($environment, $id){
    if("$($environment)$($id)" -notin $protectedObjectCache.Keys){
        $protectedObjects = api get "protectionSources/protectedObjects?environment=$environment&id=$id"
        $protectedObjectCache["$($environment)$($id)"] = $protectedObjects
    }else{
        $protectedObjects = $protectedObjectCache["$($environment)$($id)"]
    }
    return $protectedObjects
}

$environments = @($rootNode.rootNode.environment)

if($rootNode.rootNode.PSObject.PRoperties['environment']){
    foreach($environment in $rootNode.registrationInfo.environments){
        $environments = @($environments + $environment)
    }
}

foreach($environment in $environments){
    $protectedSources = getProtectedObjects $environment $parentId
    foreach($protectedSource in $protectedSources){
        $childName = $protectedSource.protectionSource.name
        $childId = $protectedSource.protectionSource.id
        if($childName -eq $object){
            $foundObject = $True
            $objectId = $childId
        }
        foreach($job in $protectedSource.protectionJobs){
            $jobName = $job.name
            $jobId = $job.id
            if($foundObject -eq $True){
                if($jobName -notin $jobNames){
                    $jobs = @($jobs + $job)
                    $jobNames = @($jobNames + $jobName)
                }
            }
        }
        if($foundObject -eq $True -and $protectedSource.protectionSource.environment -notin $dbenvironments){
            break
        }
    }
}

if('kSQL' -in $environments -or 'kOracle' -in $environments){
    $appSources = api get protectionSources?id=$parentId
}

if(!$objectId){
    Write-Host "None: Not Found" -ForegroundColor Yellow
    exit 1
}else{
    $foundProtectedObject = $false
    $objectJobIDs = @()
    foreach($job in $jobs){
        $environment = $job.environment  
        if($environment -notin $dbenvironments){
            $thisParentId = $job.parentSourceId
            $protectedObjects = getProtectedObjects $environment $thisParentId | Where-Object {$_.protectionSource.id -eq $objectId}
            foreach($protectedObject in $protectedObjects){
                foreach($protectionJob in $protectedObject.protectionJobs){
                    $objectJobIDs = @($objectJobIDs + $protectionJob.id)
                }
            }
        }else{
            $protectedObjects = getProtectedObjects $environment $parentId | Where-Object {$_.protectionSource.parentId -eq $objectId}
            foreach($protectedObject in $protectedObjects){
                foreach($protectionJob in $protectedObjects.protectionJobs){
                    $objectJobIDs = @($objectJobIDs + $protectionJob.id)
                }
            }
        }
    }
}

if(@($objectJobIds).Count -eq 0){
    Write-Host "None::Not Protected"
    exit 1
}else{
    $jobs = api get "protectionJobs?includeLastRunAndStats=true" | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false}
    foreach($job in $jobs | Where-Object id -in $objectJobIDs){
        $jobName = $job.name
        $jobList += $jobName
        $jobType = $job.environment.substring(1)
        if($jobType -eq 'SQL'){
            $sqlBackupType = $job.environmentParameters.sqlParameters.backupType
        }
        $jobReport = @{'jobName' = $jobName; 'jobType' = $jobType; 'dbList' = @(); 'objectStatus' = 'Protected'; 'objectLastRun' = 0; 'sqlBackupType' = $sqlBackupType}

        # get list of protected SQL DBs for this object
        if($job.environment -eq 'kSQL' -or $job.environment -eq 'kOracle'){
            if($job.environment -eq 'kSQL'){
                $dbList = $appSources.applicationNodes.nodes | Where-Object {$_.protectionSource.parentId -eq $objectId}
                $protectedDbList = getProtectedObjects $job.environment $objectId
            }else{
                $dbList = $appSources.applicationNodes | Where-Object {$_.protectionSource.parentId -eq $objectId}
                $protectedDbList = getProtectedObjects $job.environment $objectId
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
    
    $dbReported = $false
    if($returnData){
        return $jobReports
        exit 0
    }
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
