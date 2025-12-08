[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][int64]$pageSize = 100,
    [Parameter()][int64]$days,
    [Parameter()][array]$environment,
    [Parameter()][array]$excludeEnvironment,
    [Parameter()][string]$outputPath = '.',
    [Parameter()][switch]$localOnly
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant

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

$cluster = api get cluster
$clusterId = $cluster.id
$clusterName = $cluster.name

$outfileName = $(Join-Path -Path $outputPath -ChildPath "recoveryPoints-$clusterName.csv")
"Job Name,Job Type,Registered Source,Protected Object,Recovery Date,Local Expiry,Archive Expiry,Archive Target" | Out-File -FilePath $outfileName

if($days){
    $daysBackUsecs = timeAgo $days days
}

$etail = ""
if($environment){
    $etail = "&&entityTypes=$($environment -join ',')"
}

### find recoverable objects
if($localOnly){
    $jobs = api get protectionJobs | Where-Object {$_.isActive -ne $false}
}else{
    $jobs = api get protectionJobs
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

### find recoverable objects
foreach($job in $jobs){
    $from = 0
    $ro = api get "/searchvms?jobIds=$($job.id)&size=$pageSize&from=$from$etail"

    $environments = @('kUnknown', 'kVMware', 'kHyperV', 'kSQL', 'kView', 'kPuppeteer',
                    'kPhysical', 'kPure', 'kAzure', 'kNetapp', 'kAgent', 'kGenericNas',
                    'kAcropolis', 'kPhysicalFiles', 'kIsilon', 'kKVM', 'kAWS', 'kExchange',
                    'kHyperVVSS', 'kOracle', 'kGCP', 'kFlashBlade', 'kAWSNative', 'kVCD',
                    'kO365', 'kO365Outlook', 'kHyperFlex', 'kGCPNative', 'kAzureNative', 
                    'kAD', 'kAWSSnapshotManager', 'kGPFS', 'kRDSSnapshotManager', 'kUnknown', 'kKubernetes',
                    'kNimble', 'kAzureSnapshotManager', 'kElastifile', 'kCassandra', 'kMongoDB',
                    'kHBase', 'kHive', 'kHdfs', 'kCouchbase', 'kUnknown', 'kUnknown', 'kUnknown')

    if($ro.count -gt 0){

        while($True){
            $ro.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
                $doc = $_.vmDocument
                $jobId = $doc.objectId.jobId
                $jobName = $doc.jobName
                $objName = $doc.objectName
                $objType = $environments[$doc.registeredSource.type]
                $sourceName = $objName
                if('objectAliases' -in $doc.PSobject.Properties.Name){
                    $objAlias = $doc.objectAliases[0]
                    if($objAlias -match "vmx" -or $objAlias -match "vmtx"){
                        $sourceName = $doc.registeredSource.displayName
                    }else{
                        $sourceName = $objAlias
                    }
                }
                write-host ("`n{0} ({1}) {2} on {3}" -f $jobName, $objType, $objName, $sourceName) -ForegroundColor Green 
                $versionList = @()
                foreach($version in $doc.versions){
                    $runId = $version.instanceId.jobInstanceId
                    $startTime = $version.instanceId.jobStartTimeUsecs
                    foreach($replica in $version.replicaInfo.replicaVec){
                        $local = 0
                        $remote = 0
                        $remoteCluster = ''
                        $archive = 0
                        $archiveTarget = ''
                        if($replica.target.type -eq 1){
                            $local = $replica.expiryTimeUsecs
                        }elseif($replica.target.type -eq 3) {
                            if($replica.expiryTimeUsecs -gt $archive){
                                $archive = $replica.expiryTimeUsecs
                                $archiveTarget = $replica.target.archivalTarget.name
                            }
                        }
                        $versionList += @{'RunDate' = $startTime; 'local' = $local; 'archive' = $archive; 'archiveTarget' = $archiveTarget; 'runId' = $runId; 'startTime' = $startTime}
                    }
                }
                write-host "`n`t             RunDate           SnapExpires        ArchiveExpires" -ForegroundColor Blue
                foreach($version in $versionList){
                    if($version['local'] -eq 0){
                        $local = '-'
                    }else{
                        $local = usecsToDate $version['local']
                    }
                    if($version['archive'] -eq 0){
                        $archive = '-'
                    }else{
                        $archive = usecsToDate $version['archive']
                    }
                    $runDate = usecsToDate $version['RunDate']
                    "`t{0,20}  {1,20}  {2,20}" -f $runDate, $local, $archive
                    "$jobName,$objType,$sourceName,$objName,$runDate,$local,$archive,$($version['archiveTarget'])" | Out-File -FilePath $outfileName -Append
                }
            }
            if($ro.count -gt ($pageSize + $from)){
                $from += $pageSize
                $ro = api get "/searchvms?jobIds=$($job.id)&size=$pageSize&from=$from$etail"
            }else{
                break
            }
        }
    }
}

write-host "`nReport Saved to $outFileName`n" -ForegroundColor Blue
