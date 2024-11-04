[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][array]$vip,
    [Parameter(Mandatory=$True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][int64]$numRuns = 120,
    [Parameter()][int64]$pageSize = 1000,
    [Parameter()][int64]$days,
    [Parameter()][array]$environment,
    [Parameter()][array]$excludeEnvironment,
    [Parameter()][switch]$includeLogs,
    [Parameter()][string]$outputPath = '.'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$outfileName = $(Join-Path -Path $outputPath -ChildPath "protectedObjectsReport.csv")
"""objectName"",""lastRunStatus"",""environment"",""objectType"",""sourceName"",""AAG Name"",""policyName"",""groupName"",""lastRunTime"",""Number of Successful Backups"",""Number of Unsuccessful Backups"",""Last Successful Backup"",""Active Snapshots"",""backupStatus"",""protectionStatus"",""System Name"",""Organization Name""" | Out-File -FilePath $outfileName

$tail = ''
if($days){
    $daysBackUsecs = timeAgo $days days
    $tail = "&startTimeUsecs=$daysBackUsecs"
}

$etail = ""
if($environment){
    $etail = "&&entityTypes=$($environment -join ',')"
}

$environments = @('kUnknown', 'kVMware', 'kHyperV', 'kSQL', 'kView', 'kPuppeteer',
                  'kPhysical', 'kPure', 'kAzure', 'kNetapp', 'kAgent', 'kGenericNas',
                  'kAcropolis', 'kPhysicalFiles', 'kIsilon', 'kKVM', 'kAWS', 'kExchange',
                  'kHyperVVSS', 'kOracle', 'kGCP', 'kFlashBlade', 'kAWSNative', 'kVCD',
                  'kO365', 'kO365Outlook', 'kHyperFlex', 'kGCPNative', 'kAzureNative', 
                  'kAD', 'kAWSSnapshotManager', 'kGPFS', 'kRDSSnapshotManager', 'kUnknown', 
                  'kKubernetes', 'kNimble', 'kAzureSnapshotManager', 'kElastifile', 'kCassandra', 
                  'kMongoDB', 'kHBase', 'kHive', 'kHdfs', 'kCouchbase', 'kAuroraSnapshotManager', 
                  'kO365PublicFolders', 'kUDA', 'kO365Teams', 'kO365Group', 'kO365Exchange', 
                  'kO365OneDrive', 'kO365Sharepoint', 'kSfdc', 'kUnknown', 'kUnknown', 'kUnknown',
                  'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown')

foreach($v in $vip){
    Write-Host "`nConnecting to $v"
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -noPromptForPassword $noPrompt
    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated to $v" -ForegroundColor Yellow
        continue
    }

    $cluster = api get cluster
    $clusterId = $cluster.id
    $clusterName = $cluster.name
    $policies = api get -v2 data-protect/policies
    $sources = api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false"
    $jobs = api get -v2 "data-protect/protection-groups?&includeTenants=true"

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name | Where-Object {$_.isActive -eq $True}){
        if($job.environment -notin $excludeEnvironment -and (!$environment -or $job.environment -in $environment)){
            $jobName = $job.name
            "    $jobName"
            $jobId = ($job.id -split ':')[2]
            $tenant = $job.permissions.name
            $from = 0
            $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
            if(!$policyName){
                $policyName = '-'
            }
            # get active snapshots
            $ro = api get "/searchvms?jobIds=$($jobId)&size=$pageSize&from=$from$etail"
            $jobObjects = @{}
            if($ro.count -gt 0){
                while($True){
                    $ro.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
                        $doc = $_.vmDocument
                        if(! $localOnly -or $doc.objectId.jobUid.clusterId -eq $clusterId){
                            $objName = $doc.objectName
                            if($environments[$doc.registeredSource.type] -notin $excludeEnvironment){
                                $objType = $environments[$doc.registeredSource.type].subString(1)
                                if($objType -eq 'Unknown'){
                                    write-host $doc.registeredSource.type
                                }
                                $objAlias = ''
                                $sqlAagName = ''
                                if($doc.objectId.entity.PSObject.Properties['sqlEntity'] -and $doc.objectId.entity.sqlEntity.PSObject.Properties['dbAagName']){
                                    $sqlAagName = $doc.objectId.entity.sqlEntity.dbAagName
                                }
                                if('objectAliases' -in $doc.PSobject.Properties.Name){
                                    $objAlias = $doc.objectAliases[0]
                                    if($objAlias -eq "$objName.vmx" -or $objType -eq 'VMware'){
                                        $objAlias = ''
                                    }
                                    if($objAlias -ne ''){
                                        $sourceName = $objAlias
                                    }
                                }
                                if($objAlias -eq ''){
                                    $sourceName = $doc.registeredSource.displayName
                                }
                                $versions = $doc.versions | Sort-Object -Property {$_.instanceId.jobStartTimeUsecs}
                                $versionCount = $versions.Count
                                $jobObjects["$($doc.objectId.entity.id)"] = @{
                                    'sourceName' = $sourceName;
                                    'objName' = $objName;
                                    'sqlAagName' = $sqlAagName;
                                    'versionCount' = $versionCount;
                                    'lastRunTime' = '';
                                    'lastSuccessfulBackup' = '';
                                    'successfulBackups' = 0;
                                    'unsuccessfulBackups' = 0;
                                    'protected' = 'Unprotected';
                                    'lastRunStatus' = '';
                                    'objectType' = '';
                                }
                            }
                        }
                    }
                    if($ro.count -gt ($pageSize + $from)){
                        $from += $pageSize
                        $ro = api get "/searchvms?jobIds=$($jobId)&size=$pageSize&from=$from$etail"
                    }else{
                        break
                    }
                }
            }
            # get runs
            $endUsecs = dateToUsecs
            while($True){
                if($includeLogs){
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true$tail"
                }else{
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&runTypes=kIncremental,kFull$tail"
                }
                foreach($run in $runs.runs){
                    $localSources = @{}
                    if($run.PSObject.Properties['localBackupInfo']){
                        $backupInfo = $run.localBackupInfo
                        $snapshotInfo = 'localSnapshotInfo'
                    }else{
                        $backupInfo = $run.originalBackupInfo
                        $snapshotInfo = 'originalBackupInfo'
                    }
                    $runType = $backupInfo.runType
                    if($includeLogs -or $runType -ne 'kLog'){
                        $runStartTime = usecsToDate $backupInfo.startTimeUsecs
                        if($days -and $daysBackUsecs -gt $backupInfo.startTimeUsecs){
                            break
                        }
                        if($backupInfo.isSlaViolated){
                            $slaStatus = 'Missed'
                        }else{
                            $slaStatus = 'Met'
                        }
                        foreach($object in $run.objects){
                            if($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -eq 'kHost'){
                                $localSources["$($object.object.id)"] = $object.object.name
                            }
                        }
                        foreach($object in $run.objects){
                            $objectName = $object.object.name
                            $objectId = $object.object.id
                            
                            if($environment -notin @('kOracle', 'kSQL') -or ($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -ne 'kHost')){
                                if($object.object.PSObject.Properties['sourceId']){
                                    if($environment -in @('kOracle', 'kSQL')){
                                        $registeredSourceName = $localSources["$($object.object.sourceId)"]
                                    }else{
                                        $registeredSource = $sources.rootNodes | Where-Object {$_.rootNode.id -eq $object.object.sourceId}
                                        $registeredSourceName = $registeredSource.rootNode.name
                                    }
                                    if(!$registeredSourceName){
                                        $registeredSourceName = $objectName
                                    }
                                }else{
                                    $registeredSourceName = $objectName
                                }
                                $objectStatus = $object.$snapshotInfo.snapshotInfo.status
                                if($objectStatus -eq 'kSuccessful'){
                                    $objectStatus = 'kSuccess'
                                }
                                if($object.$snapshotInfo.snapshotInfo.startTimeUsecs){
                                    $objectStartTime = usecsToDate $object.$snapshotInfo.snapshotInfo.startTimeUsecs
                                }else{
                                    $objectStartTime = $runStartTime
                                }
                                if(! $jobObjects.ContainsKey("$objectId")){
                                    $jobObjects["$objectId"] = @{
                                        'sourceName' = $registeredSourceName;
                                        'objName' = $objectName;
                                        'versionCount' = 0;
                                        'lastRunTime' = '';
                                        'lastSuccessfulBackup' = '';
                                        'successfulBackups' = 0;
                                        'unsuccessfulBackups' = 0;
                                        'protected' = 'Unprotected';
                                        'lastRunStatus' = '';
                                        'objectType' = '';
                                    }
                                }
                                $jobObject = $jobObjects["$objectId"]
                                $jobObject["objectType"] = $object.object.objectType
                                if($job.isDeleted -ne $True){
                                    $jobObject["protected"] = 'Protected'
                                }
                                if($jobObject["lastRunStatus"] -eq ''){
                                    $jobObject["lastRunStatus"] = $objectStatus
                                    $jobObject["lastRunTime"] = $runStartTime
                                }
                                if($objectStatus -in @('kSuccess', 'kWarning')){
                                    $jobObject["successfulBackups"] += 1
                                    if($jobObject["lastSuccessfulBackup"] -eq ''){
                                        $jobObject["lastSuccessfulBackup"] = $runStartTime
                                    }
                                }else{
                                    $jobObject["unsuccessfulBackups"] += 1
                                }
                            }
                        }
                    }
                }
                if($runs.runs.Count -eq $numRuns){
                    if($runs.runs[-1].PSObject.Properties['localBackupInfo']){
                        $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
                    }else{
                        $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs - 1
                    }
                    if($endUsecs -lt 0 -or $endUsecs -lt $daysBackUsecs){
                        break
                    }
                }else{
                    break
                }
            }
            foreach($objId in $jobObjects.Keys){
                $jobObject = $jobObjects["$objId"]
                if($job.environment -notin @('kOracle', 'kSQL') -or ($job.environment -in @('kOracle', 'kSQL') -and $jobObject["objectType"] -ne 'kHost')){
                    $backupStatus = "HasNoSuccessfulBackups"
                    if($jobObject["versionCount"] -gt 0){
                        $backupStatus = "HasSuccessfulBackups"
                    }
                    """$($jobObject["objName"])"",""$($jobObject["lastRunStatus"])"",""$($job.environment)"",""$($jobObject["objectType"])"",""$($jobObject["sourceName"])"",""$($jobObject["sqlAagName"])"",""$policyName"",""$($job.name)"",""$($jobObject["lastRunTime"])"",""$($jobObject["successfulBackups"])"",""$($jobObject["unsuccessfulBackups"])"",""$($jobObject["lastSuccessfulBackup"])"",""$($jobObject["versionCount"])"",""$backupStatus"",""$($jobObject["protected"])"",""$clusterName"",""$tenant""" | Out-File -FilePath $outfileName -Append
                }
            }
        }
    }
}

write-host "`nReport Saved to $outFileName`n"
