[CmdletBinding()]
param (
    [Parameter()][string]$heliosVip = 'helios.cohesity.com',
    [Parameter()][string]$heliosUsername = 'helios',
    [Parameter()][string]$heliosPassword,
    [Parameter()][string]$clusterVip,
    [Parameter()][string]$clusterUserName,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][string]$tenant,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter(Mandatory=$True)][string]$sourceCluster = $null,
    [Parameter()][int64]$pageSize = 1000,
    [Parameter()][int64]$days = 90,
    [Parameter()][array]$environment,
    [Parameter()][array]$excludeEnvironment,
    [Parameter()][string]$outputPath = '.',
    [Parameter()][int]$dayRange = 7,
    [Parameter()][string]$remoteCluster,
    [Parameter()][switch]$omitSourceClusterColumn
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
"Connecting to Helios..."
apiauth -vip $heliosVip -username $heliosUsername -domain 'local' -passwd $heliosPassword -helios

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($sourceCluster){
        $thisCluster = heliosCluster $sourceCluster
    }else{
        Write-Host "Please provide -sourceCluster when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

if($remoteCluster){
    $remoteClusters = api get remoteClusters
    $thisRemoteCluster = $remoteClusters | Where-Object name -eq $remoteCluster
    if(! $thisRemoteCluster){
        Write-Host "remote cluster $remoteCluster not found!" -ForegroundColor Yellow
        exit 1
    }
}


$cluster = api get cluster
$clusterId = $cluster.id
$clusterName = $cluster.name
if($remoteCluster){
    $outfileName = $(Join-Path -Path $outputPath -ChildPath "activeSnapshots-$remoteCluster-replicatedFrom-$clusterName.csv")
}else{
    $outfileName = $(Join-Path -Path $outputPath -ChildPath "activeSnapshots-ALL-replicatedFrom-$clusterName.csv")
}

if($omitSourceClusterColumn){
    """Cluster Name"",""Job Name"",""Job Type"",""Source Name"",""Object Name"",""SQL AAG Name"",""Active Snapshots"",""Oldest Snapshot"",""Newest Snapshot""" | Out-File -FilePath $outfileName
}else{
    """Cluster Name"",""Job Name"",""Job Type"",""Source Name"",""Object Name"",""SQL AAG Name"",""Active Snapshots"",""Oldest Snapshot"",""Newest Snapshot"",""Source Cluster""" | Out-File -FilePath $outfileName
}

$nowUsecs = dateToUsecs (Get-Date)
if($days){
    $daysBackUsecs = timeAgo $days days
}

$csvFileName = $(Join-Path -Path $outputPath -ChildPath "reporttemp-$clusterName-$remoteCluster.csv")

$dayRangeUsecs = $dayRange * 86400000000

# build time ranges
$ranges = @()
$gotAllRanges = $False
$uStart = $daysBackUsecs
$uEnd = $nowUsecs
$thisUend = $nowUsecs
$thisUstart = $daysBackUsecs
while($gotAllRanges -eq $False){
    if(($thisUend - $uStart) -gt $dayRangeUsecs){
        $thisUstart = $thisUend - $dayRangeUsecs
        $ranges = @($ranges + @{'start' = $thisUstart; 'end' = $thisUend})
        $thisUend = $thisUstart - 1
    }else{
        $ranges = @($ranges + @{'start' = $uStart; 'end' = $thisUend})
        $gotAllRanges = $True
    }
}

$environmentFilter = @{
    "attribute" = "environment";
    "filterType" = "In";
    "inFilterParams" = @{
        "attributeDataType" = "String";
        "stringFilterValues" = @(
            $environment
        );
        "attributeLabels" = @(
            $environment
        )
    }
}

"Gathering Helios data..."
$data = @()
$gotHeadings = $False
foreach($range in $ranges){
    $csvlines = @()
    $reportParams = @{
        "limit" = @{
            "size" = 50000
        };
        "timezone" = "America/New_York";
        "filters" = @(
            @{
                "timeRangeFilterParams" = @{
                    "upperBound" = [int64]$range.end;
                    "lowerBound" = [int64]$range.start
                };
                "attribute" = "date";
                "filterType" = "TimeRange"
            };
            @{
                "systemsFilterParams" = @{
                    "systemNames" = @(
                        "$($cluster.name)"
                    );
                    "systemIds" = @(
                        "$($cluster.id):$($cluster.incarnationId)"
                    )
                };
                "attribute" = "systemId";
                "filterType" = "Systems"
            };
            @{
                "attribute" = "backupType";
                "inFilterParams" = @{
                    "stringFilterValues" = @(
                        "kRegular";
                        "kFull";
                        "kSystem"
                    );
                    "attributeDataType" = "String";
                    "attributeLabels" = @(
                        "Incremental";
                        "Full";
                        "System"
                    )
                };
                "filterType" = "In"
            }
        );
        "sort" = $null
    }

    if($environment){
        $reportParams.filters = @($reportParams.filters + $environmentFilter)
    }

    $preview = api post -reportingV2 "components/600/preview" $reportParams
    if(!$gotHeadings){
        $attributes = $preview.component.config.xlsxParams.attributeConfig
        $attributes.attributeName -join ',' | Out-File -FilePath $csvFileName
        $gotHeadings = $True
    }
    $data = @($data + $preview.component.data)
}
$data | Export-CSV -Append -Path $csvFileName
$csv = Import-CSV -Path $csvFileName

if($clusterUserName){
    "Connecting to cluster..."
    if(! $clusterVip){
        $clusterVip = $clusterName
    }
    ### authenticate
    apiauth -vip $clusterVip -username $clusterUsername -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant

    # select helios/mcm managed cluster
    if($USING_HELIOS){
        if($clusterName){
            $thisCluster = heliosCluster $clusterName
        }else{
            Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
            exit 1
        }
    }

    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated" -ForegroundColor Yellow
        exit 1
    }
}

$jobs = api get "protectionJobs?isActive=true&onlyReturnBasicSummary=true&useCachedData=true"

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

if($environment){
    $jobs = $jobs | Where-Object {$_.environment -in $environment}
}

foreach($job in $jobs | Sort-Object -Property name){
    $endUsecs = $nowUsecs
    $replicatedRuns = @{}
    $jobObjects = @{}
    $job.name
    $aagName = @{}

    while($True){
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$pageSize&startTimeUsecs=$daysBackUsecs&endTimeUsecs=$endUsecs&runTypes=kRegular&runTypes=kFull&excludeTasks=true&useCachedData=true"
        foreach($run in $runs){
            $runStartTime = usecsToDate $run.backupRun.stats.startTimeUsecs
            if($remoteCluster){
                $copyRuns = $run.copyRun | Where-Object {$_.target.type -eq 'kRemote' -and $_.target.replicationTarget.clusterName -eq $remoteCluster -and $_.status -eq 'kSuccess'}
            }else{
                $copyRuns = $run.copyRun | Where-Object {$_.target.type -eq 'kRemote' -and $_.status -eq 'kSuccess'}
            }
            foreach($copyRun in $copyRuns){
                $expiry = $copyRun.expiryTimeUsecs
                if($expiry -gt $nowUsecs){
                    $timeKey = "$([Int64]($run.backupRun.stats.startTimeUsecs / 900000000) * 900000000)"
                    if($timeKey -notin $replicatedRuns){
                        $replicatedRuns[$timeKey] = @($copyRun.target.replicationTarget.clusterName)
                    }else{
                        $replicatedRuns[$timeKey] = @($replicatedRuns[$timeKey] + $copyRun.target.replicationTarget.clusterName)
                    }
                }
            }
        }
        if($runs.Count -eq $pageSize){
            $endUsecs = $runs[-1].backupRun.stats.endTimeUsecs - 1
        }else{
            break
        }
    }
    if($replicatedRuns.Keys.Count -gt 0){
        $objectRuns = $csv | Where-Object {$_.groupName -eq $job.name -and "$([Int64]($_.runStartTimeUsecs / 900000000) * 900000000)" -in $replicatedRuns.Keys}
        foreach($o in $objectRuns){
            $keyName = "$($o.sourceName);;$($o.objectName)"
            if("$keyName" -notin $jobObjects.Keys){
                $jobObjects["$keyName"] = @{
                    'objectName' = $o.objectName;
                    'sourceName' = $o.sourceName;
                    'active' = 1;
                    'newest' = $o.runStartTimeUsecs;
                    'oldest' = $o.runStartTimeUsecs;
                    'targets' = $replicatedRuns["$([Int64]($o.runStartTimeUsecs / 900000000) * 900000000)"]
                }
            }else{
                if($o.runStartTimeUsecs -gt $jobObjects[$keyName]['newest']){
                    $jobObjects[$keyName]['newest'] = $o.runStartTimeUsecs
                }
                if($o.runStartTimeUsecs -lt $jobObjects[$keyName]['oldest']){
                    $jobObjects[$keyName]['oldest'] = $o.runStartTimeUsecs
                }
                $jobObjects[$keyName]['active'] += 1
            }
        }

        if($job.environment -eq 'kSQL'){
            $from = 0
            $ro = api get "/searchvms?jobIds=$($job.id)&size=$pageSize&from=$from&onlyLatestVersion=true"
            
            if($ro.count -gt 0){
                while($True){
                    $ro.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
                        $doc = $_.vmDocument
                        $objName = $doc.objectName
                        $sqlAagName = $doc.objectId.entity.sqlEntity.dbAagName
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
                        $aagName["$($sourceName);;$($objName)"] = $sqlAagName
                    }
                    if($ro.count -gt ($pageSize + $from)){
                        $from += $pageSize
                        $ro = api get "/searchvms?jobIds=$($job.id)&size=$pageSize&from=$from&onlyLatestVersion=true"
                    }else{
                        break
                    }
                }
            }
        }

        foreach($keyName in $jobObjects.Keys | Sort-Object){
            "    {0}: {1}" -f $jobObjects[$keyName]['objectName'], $jobObjects[$keyName]['active']
            foreach($target in $jobObjects[$keyName]['targets']){
                if($omitSourceClusterColumn){
                    """$target"",""$($job.name)"",""$($job.environment)"",""$($jobObjects[$keyName]['sourceName'])"",""$($jobObjects[$keyName]['objectName'])"",""$($aagName[$keyName])"",""$($jobObjects[$keyName]['active'])"",""$(usecsToDate $jobObjects[$keyName]['oldest'])"",""$(usecsToDate $jobObjects[$keyName]['newest'])""" | Out-File -FilePath $outfileName -Append
                }else{
                    """$target"",""$($job.name)"",""$($job.environment)"",""$($jobObjects[$keyName]['sourceName'])"",""$($jobObjects[$keyName]['objectName'])"",""$($aagName[$keyName])"",""$($jobObjects[$keyName]['active'])"",""$(usecsToDate $jobObjects[$keyName]['oldest'])"",""$(usecsToDate $jobObjects[$keyName]['newest'])"",""$clusterName""" | Out-File -FilePath $outfileName -Append
                }
            }
        }
    }
}

write-host "`nReport Saved to $outFileName`n"
