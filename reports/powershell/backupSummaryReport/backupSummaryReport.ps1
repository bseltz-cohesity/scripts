### process commandline arguments
[CmdletBinding()]
param (
   [Parameter()][string]$vip = 'helios.cohesity.com',
   [Parameter()][string]$username = 'helios',
   [Parameter()][string]$domain = 'local',
   [Parameter()][switch]$useApiKey,
   [Parameter()][string]$password = $null,
   [Parameter()][switch]$mcm,
   [Parameter()][string]$mfaCode = $null,
   [Parameter()][switch]$emailMfaCode,
   [Parameter()][string]$clusterName = $null,
   [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB',
   [Parameter()][int]$daysBack = 7
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

### select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

$environments = @('kUnknown', 'kVMware', 'kHyperV', 'kSQL', 'kView', 'kPuppeteer',
                'kPhysical', 'kPure', 'kAzure', 'kNetapp', 'kAgent', 'kGenericNas',
                'kAcropolis', 'kPhysicalFiles', 'kIsilon', 'kKVM', 'kAWS', 'kExchange',
                'kHyperVVSS', 'kOracle', 'kGCP', 'kFlashBlade', 'kAWSNative', 'kVCD',
                'kO365', 'kO365Outlook', 'kHyperFlex', 'kGCPNative', 'kAzureNative', 
                'kAD', 'kAWSSnapshotManager', 'kGPFS', 'kRDSSnapshotManager', 'kUnknown', 'kKubernetes',
                'kNimble', 'kAzureSnapshotManager', 'kElastifile', 'kCassandra', 'kMongoDB',
                'kHBase', 'kHive', 'kHdfs', 'kCouchbase', 'kUnknown', 'kUnknown', 'kUnknown')

$slaViolation = @{$false = 'Pass'; $True = 'Fail'}

$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning')

$today = Get-Date

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "BackupSummary-$($cluster.name)-$dateString.csv"
"Protection Group,Type,Source,Successful Runs,Failed Runs,Last Run Successful Objects,Last Run Failed Objects,Data Read Total $unit,Data Written Total $unit,SLA Violation,Last Run Status,Last Run Date,Last Run Copy Status,Message" | Out-File -FilePath $outfileName

$now = Get-Date
$nowUsecs = dateToUsecs $now
$daysBackUsecs = dateToUsecs $now.AddDays(-$daysBack)

$summary = api get "/backupjobssummary?_includeTenantInfo=true&allUnderHierarchy=false&endTimeUsecs=$nowUsecs&onlyReturnJobDescription=false&startTimeUsecs=$daysBackUsecs"

foreach($job in $summary | Sort-Object -Property {$_.backupJobSummary.jobDescription.name}){

    $jobName = $job.backupJobSummary.jobDescription.name
    $jobType = $environments[$job.backupJobSummary.jobDescription.type].subString(1)
    $source = $job.backupJobSummary.jobDescription.parentSource.displayName
    if($jobType -eq 'View'){
        $source = $job.backupJobSummary.jobDescription.sources[0].entities[0].displayName
    }
    if($jobType -eq 'Puppeteer'){
        $source = $job.backupJobSummary.jobDescription.preScript.remoteHostParams.hostAddress
    }
    if($job.backupJobSummary.PSObject.Properties['lastProtectionRun']){
        $successfulRuns = 0
        if($job.backupJobSummary.PSObject.Properties['numSuccessfulJobRuns']){
            $successfulRuns = $job.backupJobSummary.numSuccessfulJobRuns
        }
        $failedRuns = 0
        if($job.backupJobSummary.PSObject.Properties['numFailedJobRuns']){
            $failedRuns = $job.backupJobSummary.numFailedJobRuns
        }
        $dateRead = $job.backupJobSummary.totalBytesReadFromSource
        $dataWritten = $job.backupJobSummary.totalPhysicalBackupSizeBytes
        $slaViolated = 'Pass'
        if($job.backupJobSummary.lastProtectionRun.backupRun.base.PSObject.Properties['slaViolated']){
            $slaViolated = $slaViolation[$job.backupJobSummary.lastProtectionRun.backupRun.base.slaViolated]
        }
        $lastRunStatus = $job.backupJobSummary.lastProtectionRun.backupRun.base.publicStatus.subString(1)
        if($lastRunStatus -eq 'Warning'){
            $message = $job.backupJobSummary.lastProtectionRun.backupRun.base.warnings[0].errorMsg
        }elseif($lastRunStatus -eq 'Failure'){
            $message = $job.backupJobSummary.lastProtectionRun.backupRun.base.error.errorMsg
        }else{
            $message = ''
        }
        if($message.length -gt 100){
            $message = $message.subString(0,100)
        }
        $lastRunDate = usecsToDate $job.backupJobSummary.lastProtectionRun.backupRun.base.startTimeUsecs
        $lastRunSuccessObjects = $job.backupJobSummary.lastProtectionRun.backupRun.numSuccessfulTasks
        $lastRunFailedObjects = $job.backupJobSummary.lastProtectionRun.backupRun.numFailedTasks
        $copyTaskStatus = '-'
        if($job.backupJobSummary.lastProtectionRun.copyRun.Count -gt 0 -and $lastRunStatus -ne 'Running'){
            $copyTaskStatus = 'Success'
            foreach($copyTask in $job.backupJobSummary.lastProtectionRun.copyRun){
                if($copyTask.status -ne '2'){
                    $copyTaskStatus = 'Failed'
                }
            }
        }
        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}"",""{12}"",""{13}""" -f $jobName, $jobType, $source, $successfulRuns, $failedRuns, $lastRunSuccessObjects, $lastRunFailedObjects, (toUnits $dateRead), (toUnits $dataWritten), $slaViolated, $lastRunStatus, $lastRunDate, $copyTaskStatus, $message | Tee-Object -FilePath $outfileName -Append    
    }
}

"`nOutput saved to $outfileName`n"