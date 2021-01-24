[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'GiB'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$clusterName = $cluster.name

$dateString = (get-date).ToString("yyyy-MM-dd")
$outfileName = "$clusterName-FETB-$dateString.csv"

$environments = @('kUnknown', 'kVMware', 'kHyperV', 'kSQL', 'kView', 'kPuppeteer', 
                  'kPhysical', 'kPure', 'kAzure', 'kNetapp', 'kAgent', 'kGenericNas', 
                  'kAcropolis', 'kPhysicalFiles', 'kIsilon', 'kKVM', 'kAWS', 'kExchange', 
                  'kHyperVVSS', 'kOracle', 'kGCP', 'kFlashBlade', 'kAWSNative', 'kVCD',
                  'kO365', 'kO365Outlook', 'kHyperFlex', 'kGCPNative', 'kAzureNative',
                  'kAD', 'kAWSSnapshotManager', 'kUnknown', 'kUnknown', 'kUnknown', 'kUnknown')

$nasEnvironments = @('kNetapp', 'kIsilon', 'kGenericNas', 'kFlashBlade', 'kGPFS', 'kElastifile')

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

"Job Name,Object Name,Object Type,Logical Size ($unit),Unique Size ($unit)" | Out-File -FilePath $outfileName

# gather capacity for servers
$serverReport = api get /reports/objects/storage?msecsBeforeEndTime=0
foreach($server in $serverReport | Sort-Object -Property jobName, name){
    $jobName = $server.jobName
    $serverName = $server.name
    $serverType = ($environments[$server.entity.type]).Substring(1)
    if($server.PSObject.Properties['dataPoints']){
        $logicalBytes = $server.dataPoints[0].logicalSizeBytes
        $uniqueBytes = $server.dataPoints[0].primaryPhysicalSizeBytes
        "{0},{1},{2},""{3}"",""{4}""" -f $jobName, $serverName, $serverType, (toUnits $logicalBytes), (toUnits $uniqueBytes) | Tee-Object -FilePath $outfileName -Append    
    }
}

# gather capacoty for NAS backups
$jobs = api get protectionJobs?includeLastRunAndStats=true | Where-Object {$_.environment -in $nasEnvironments}
foreach($job in $jobs | Where-Object{$_.isDeleted -ne $True} | Sort-Object -Property name){
    $jobName = $job.name
    $jobType = $job.environment.Substring(1)
    foreach($volume in $job.lastRun.backupRun.sourceBackupStatus){
        $volumeName = $volume.source.name
        $logicalBytes = $volume.stats.totalLogicalBackupSizeBytes
        "{0},{1},{2},""{3}"",""{4}""" -f $jobName, $volumeName, $jobType, (toUnits $logicalBytes), 0 | Tee-Object -FilePath $outfileName -Append    
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
    "{0},{1},{2},""{3}"",""{4}""" -f $jobName, $viewName, 'View', (toUnits $logicalBytes), 0 | Tee-Object -FilePath $outfileName -Append
}

"`nOutput written to $outfileName"