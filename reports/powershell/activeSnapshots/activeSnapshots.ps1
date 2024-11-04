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
    [Parameter()][int64]$pageSize = 1000,
    [Parameter()][int64]$days,
    [Parameter()][array]$environment,
    [Parameter()][array]$excludeEnvironment,
    [Parameter()][string]$outputPath = '.',
    [Parameter()][switch]$localOnly,
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
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
$outfileName = $(Join-Path -Path $outputPath -ChildPath "activeSnapshots-$clusterName.csv")
"""Cluster Name"",""Job Name"",""Job Type"",""Source Name"",""Object Name"",""SQL AAG Name"",""Active Snapshots"",""Oldest Snapshot"",""Newest Snapshot""" | Out-File -FilePath $outfileName

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

foreach($job in $jobs){
    $from = 0
    $ro = api get "/searchvms?jobIds=$($job.id)&size=$pageSize&from=$from$etail"
    
    if($ro.count -gt 0){
    
        while($True){
            $ro.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
                $doc = $_.vmDocument
                if(! $localOnly -or $doc.objectId.jobUid.clusterId -eq $clusterId){
                    $jobId = $doc.objectId.jobId
                    $jobName = $doc.jobName
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
                        if($days){
                            $versions = $versions | Where-Object {$_.instanceId.jobStartTimeUsecs -ge $daysBackUsecs}
                        }
                        
                        $versionCount = $versions.Count
                        if($versionCount -gt 0){
                            $newestSnapshotDate = usecsToDate $versions[-1].instanceId.jobStartTimeUsecs
                            $oldestSnapshotDate = usecsToDate $versions[0].instanceId.jobStartTimeUsecs
                        }else{
                            $newestSnapshotDate = ''
                            $oldestSnapshotDate = ''
                        }
                        write-host ("{0} ({1}) {2}: {3}" -f $jobName, $objType, $objName, $versionCount)
                        """$($cluster.name)"",""$jobName"",""$objType"",""$sourceName"",""$objName"",""$sqlAagName"",""$versionCount"",""$oldestSnapshotDate"",""$newestSnapshotDate""" | Out-File -FilePath $outfileName -Append
                    }
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

write-host "`nReport Saved to $outFileName`n"

if($smtpServer -and $sendFrom -and $sendTo){
    write-host "Sending report to $([string]::Join(", ", $sendTo))"
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "active snapshots report for $($cluster.name)" -Body "active snapshots report for $($cluster.name)`n`n" -Attachments $outFileName -WarningAction SilentlyContinue
    }
}
