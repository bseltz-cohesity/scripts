[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'GiB',
    [Parameter()][switch]$localOnly
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$clusterName = $cluster.name
$clusterId = $cluster.id

$dateString = (get-date).ToString("yyyy-MM-dd")
$outfileName = "$clusterName-FETB-$dateString.csv"

$environments = @('kUnknown', 'kVMware', 'kHyperV', 'kSQL', 'kView', 'kPuppeteer', 
                  'kPhysical', 'kPure', 'kAzure', 'kNetapp', 'kAgent', 'kGenericNas', 
                  'kAcropolis', 'kPhysicalFiles', 'kIsilon', 'kKVM', 'kAWS', 'kExchange', 
                  'kHyperVVSS', 'kOracle', 'kGCP', 'kFlashBlade', 'kAWSNative', 'kVCD',
                  'kO365', 'kO365Outlook', 'kHyperFlex', 'kGCPNative', 'kAzureNative',
                  'kAD', 'kAWSSnapshotManager', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown')

$nasEnvironments = @('kNetapp', 'kIsilon', 'kGenericNas', 'kFlashBlade', 'kGPFS', 'kElastifile')

$serverEnvironments = @('kUnknown', 'kVMware', 'kHyperV', 'kPhysical', 'kAcropolis', 'kPhysicalFiles', 
                        'kKVM', 'kAWS', 'kHyperVVSS', 'kGCP', 'kAWSNative', 'kVCD',
                        'kGCPNative', 'kAzureNative', 'kAD')

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

"Job Name,Object Name,Object Type,Logical Size ($unit),Unique Size ($unit)" | Out-File -FilePath $outfileName

$uniqueBytesTable = @{}
$entityLogical = @{}

"Gathering storage statistics..."

# gather unique capacity for servers
$serverReport = api get /reports/objects/storage?msecsBeforeEndTime=0
foreach($server in $serverReport | Sort-Object -Property jobName, name){
    $serverName = $server.name
    if($server.PSObject.Properties['dataPoints']){
        $uniqueBytes = $server.dataPoints[0].primaryPhysicalSizeBytes
        if($uniqueBytes -gt 0){
            $uniqueBytesTable[$serverName] = $uniqueBytes
        }
    }
}
$jobs = (api get -v2 "data-protect/protection-groups?isDeleted=false&&includeTenants=true").protectionGroups | Sort-Object -Property name

if($localOnly){
    $jobs = $jobs | Where-Object isActive -eq $True
}

# gather capacity for protected objects
foreach($job in $jobs){
    $jobId = $job.id
    $jobName = $job.name
    $jobType = $job.environment.Substring(1)
    $runs = api get -v2 "data-protect/protection-groups/$jobId/runs?includeTenants=true&includeObjectDetails=true&numRuns=5"

    foreach($run in $runs.runs){
        foreach($server in ($run.objects | Sort-Object -Property {$_.object.name})){
            $serverName = $server.object.name
            $logicalBytes = $server.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes
            if($serverName -in $uniqueBytesTable.Keys){
                $uniqueBytes = $uniqueBytesTable[$serverName]
            }else{
                $uniqueBytes = $logicalBytes
            }
            if($serverName -notin $entityLogical.Keys){
                $entityLogical[$serverName] = $logicalBytes
                "{0},{1},{2},""{3}"",""{4}""" -f $jobName, $serverName, $jobType, (toUnits $logicalBytes), (toUnits $uniqueBytes) | Tee-Object -FilePath $outfileName -Append
            }
        }
    }
}

# gather capacity for views
$views = api get views
foreach($view in $views.views | Sort-Object -Property name){
    $viewName = $view.name
    $logicalBytes = $view.logicalUsageBytes
    if($view.PSObject.Properties['viewProtection']){
        $jobName = $view.viewProtection.protectionJobs[0].jobName
    }else{
        $jobName = '-'
    }
    if($viewName -notin $entityLogical.Keys){
        $entityLogical[$viewName] = $logicalBytes
        "{0},{1},{2},""{3}"",""{4}""" -f $jobName, $viewName, 'View', (toUnits $logicalBytes), (toUnits $logicalBytes) | Tee-Object -FilePath $outfileName -Append
    }
}

"`nOutput written to $outfileName"
