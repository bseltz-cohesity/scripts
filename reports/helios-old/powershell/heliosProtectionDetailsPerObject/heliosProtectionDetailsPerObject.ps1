### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$slurp = 20,
    [Parameter()][int]$pageCount = 6200,
    [Parameter()][string]$startDate = '',
    [Parameter()][string]$endDate = '',
    [Parameter()][switch]$thisCalendarMonth,
    [Parameter()][switch]$lastCalendarMonth,
    [Parameter()][int]$days = 31
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -helios

### determine start and end dates
$today = Get-Date

if($startDate -ne '' -and $endDate -ne ''){
    $uStart = dateToUsecs $startDate
    $uEnd = dateToUsecs $endDate
}elseif ($thisCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)))
    $uEnd = dateToUsecs ($today)
}elseif ($lastCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddMonths(-1))
    $uEnd = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddSeconds(-1))
}else{
    $uStart = timeAgo $days 'days'
    $uEnd = dateToUsecs ($today)
}

$start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
$end = (usecsToDate $uEnd).ToString('yyyy-MM-dd')

$outfile = "protectionDetailsPerObject--$start--$end.csv"

$MiB = 1024 * 1024

"Cluster,Object,Type,StartTime,JobName,Status,RunType,MB Read,MB Logical,Message" | Out-File -FilePath $outfile

foreach($cluster in heliosClusters){
    heliosCluster $cluster

    "`n-------------------"
    "$($cluster.name)"
    "-------------------`n"

    $entities = api get "/entitiesOfType?acropolisEntityTypes=kVirtualMachine&adEntityTypes=kRootContainer&adEntityTypes=kDomainController&agentEntityTypes=kGroup&agentEntityTypes=kHost&allUnderHierarchy=true&awsEntityTypes=kEC2Instance&awsEntityTypes=kRDSInstance&azureEntityTypes=kVirtualMachine&environmentTypes=kAcropolis&environmentTypes=kAD&environmentTypes=kAWS&environmentTypes=kAgent&environmentTypes=kAzure&environmentTypes=kFlashblade&environmentTypes=kGCP&environmentTypes=kGenericNas&environmentTypes=kGPFS&environmentTypes=kHyperFlex&environmentTypes=kHyperV&environmentTypes=kIsilon&environmentTypes=kKVM&environmentTypes=kNetapp&environmentTypes=kO365&environmentTypes=kOracle&environmentTypes=kPhysical&environmentTypes=kPure&environmentTypes=kSQL&environmentTypes=kView&environmentTypes=kVMware&flashbladeEntityTypes=kFileSystem&gcpEntityTypes=kVirtualMachine&genericNasEntityTypes=kHost&gpfsEntityTypes=kFileset&hyperflexEntityTypes=kServer&hypervEntityTypes=kVirtualMachine&isProtected=true&isilonEntityTypes=kMountPoint&kvmEntityTypes=kVirtualMachine&netappEntityTypes=kVolume&office365EntityTypes=kOutlook&office365EntityTypes=kMailbox&office365EntityTypes=kUsers&office365EntityTypes=kGroups&office365EntityTypes=kSites&office365EntityTypes=kUser&office365EntityTypes=kGroup&office365EntityTypes=kSite&oracleEntityTypes=kDatabase&physicalEntityTypes=kHost&physicalEntityTypes=kWindowsCluster&physicalEntityTypes=kOracleRACCluster&physicalEntityTypes=kOracleAPCluster&pureEntityTypes=kVolume&sqlEntityTypes=kDatabase&viewEntityTypes=kView&viewEntityTypes=kViewBox&vmwareEntityTypes=kVirtualMachine"
    $entities = $entities | Sort-Object -Property type, displayName

    $i = 0
    while($i -lt $entities.Length){
        $theseEntities = $entities[$i..($i + $slurp -1)]
        $uri =  "reports/protectionSourcesJobRuns?startTimeUsecs=$uStart&endTimeUsecs=$uEnd&pageCount=$pageCount"
        foreach($entity in $theseEntities){
            $uri += "&protectionSourceIds=$($entity.id)"
        }
        $report = api get $uri
        foreach($source in $report.protectionSourceJobRuns){
            foreach($snapshot in $source.snapshotsInfo){
                if($snapshot.PSObject.Properties['message']){
                    $message = $snapshot.message.replace(',',';').replace("`n",' - ')
                }else{
                    $message = ""
                }
                "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f $cluster.name,
                                                             $source.protectionSource.name,
                                                             $source.protectionSource.environment.subString(1),
                                                             (usecsToDate $snapshot.jobRunStartTimeUsecs),
                                                             $snapshot.jobName,
                                                             $snapshot.runStatus.subString(1),
                                                             $snapshot.runType.subString(1).replace('Regular', 'Incremental'),
                                                             [math]::Round(($snapshot.numBytesRead / $MiB), 2),
                                                             [math]::Round(($snapshot.numLogicalBytesProtected / $MiB), 2),
                                                             $message | Tee-Object -FilePath $outfile -Append | Write-Host
            }
        }
        $i += $slurp
    }
}
