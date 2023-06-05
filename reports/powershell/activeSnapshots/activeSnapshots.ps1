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
    [Parameter()][string]$environment = $null,
    [Parameter()][string]$outputPath = '.'
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
$clusterName = $cluster.name
$outfileName = $(Join-Path -Path $outputPath -ChildPath "activeSnapshots-$clusterName.csv")
"""Cluster Name"",""Job Name"",""Job Type"",""Source Name"",""Object Name"",""Active Snapshots"",""Oldest Snapshot"",""Newest Snapshot""" | Out-File -FilePath $outfileName

if($days){
    $daysBackUsecs = timeAgo $days days
}

$etail = ""
if($environment){
    $etail = "&&entityTypes=$environment"
}

### find recoverable objects
$from = 0
$ro = api get "/searchvms?size=$pageSize&from=$from$etail"

$environments = @('Unknown', 'VMware', 'HyperV', 'SQL', 'View', 'Puppeteer',
                'Physical', 'Pure', 'Azure', 'Netapp', 'Agent', 'GenericNas',
                'Acropolis', 'PhysicalFiles', 'Isilon', 'KVM', 'AWS', 'Exchange',
                'HyperVVSS', 'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
                'O365', 'O365Outlook', 'HyperFlex', 'GCPNative', 'AzureNative', 
                'AD', 'AWSSnapshotManager', 'GPFS', 'RDSSnapshotManager', 'Unknown', 'Kubernetes',
                'Nimble', 'AzureSnapshotManager', 'Elastifile', 'Cassandra', 'MongoDB',
                'HBase', 'Hive', 'Hdfs', 'Couchbase', 'Unknown', 'Unknown', 'Unknown')

if($ro.count -gt 0){

    while($True){
        $ro.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
            $doc = $_.vmDocument
            # $doc | ConvertTo-Json -Depth 2
            $jobId = $doc.objectId.jobId
            $jobName = $doc.jobName
            $objName = $doc.objectName
            $objType = $environments[$doc.registeredSource.type]
            $objAlias = ''
            if('objectAliases' -in $doc.PSobject.Properties.Name){
                $objAlias = $doc.objectAliases[0]
                if($objAlias -eq "$objName.vmx" -or $objType -eq 'VMware'){
                    $objAlias = ''
                }
                if($objAlias -ne ''){
                    $sourceName = $objAlias
                    # $objName = "$objAlias/$objName"
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
            """$($cluster.name)"",""$jobName"",""$objType"",""$sourceName"",""$objName"",""$versionCount"",""$oldestSnapshotDate"",""$newestSnapshotDate""" | Out-File -FilePath $outfileName -Append
        }
        if($ro.count -gt ($pageSize + $from)){
            $from += $pageSize
            $ro = api get "/searchvms?size=$pageSize&from=$from$etail"
        }else{
            break
        }
    }
    write-host "`nReport Saved to $outFileName`n"
}
