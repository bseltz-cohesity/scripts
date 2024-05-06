# process commandline arguments
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
    [Parameter()][switch]$yesterdayOnly
)

# source the cohesity-api helper code
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

# date range
$now = Get-Date
$midnight = Get-Date -Hour 0 -Minute 0 -Second 0
$yesterday = $midnight.AddDays(-1)
$nowUsecs = dateToUsecs $now
$midnightUsecs = dateToUsecs $midnight
$yesterdayUsecs = dateToUsecs $yesterday
if($yesterdayOnly){
    $endTimeUsecs = $midnightUsecs
}else{
    $endTimeUsecs = $nowUsecs
}

# output file
$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "dailyObjectStatus-$($cluster.name)-$dateString.csv")
"Job Name,Job Type,Object Name,Status,Last Run,Duration (Seconds),Message" | Out-File -FilePath $outputfile

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&includeLastRunInfo=false"

$o365Sources = api get protectionSources?environments=kO365
$o365Users = ($o365Sources.nodes | Where-Object {$_.protectionSource.office365ProtectionSource.type -eq 'kUsers'}).nodes | Select-Object -Property @{l='id'; e={$_.protectionSource.id}}, @{l='smtpAddress'; e={$_.protectionSource.office365ProtectionSource.primarySMTPAddress}}
$o365Index = @{}
$o365Users | ForEach-Object {
    $o365Index[$_.id] = $_.smtpAddress
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    "{0}" -f $job.name
    $lastRun = (api get -v2 "data-protect/protection-groups/$($job.id)/runs/?numRuns=2&includeObjectDetails=true&endTimeUsecs=$endTimeUsecs").runs | Where-Object {$_.localBackupInfo.status -ne 'Running'}
    if($lastRun.Count -gt 0){
        $lastRun = $lastRun[0]
        $lastRun.localBackupInfo.status
        foreach($entity in $lastRun.objects | Sort-Object -Property {$_.object.name}){
            $objectName = $entity.object.name
            if($entity.object.environment -eq 'kO365' -and $entity.object.objectType -eq 'kUser'){
                $altObjectName = $o365Index[$entity.object.id]
                if($altObjectName -and $altObjectName -ne ''){
                    $objectName = $altObjectName
                }
            }
            if($entity.object.environment -eq 'kO365' -and $entity.object.objectType -eq 'kSite'){
                if($entity.object.PSObject.Properties['sharepointSiteSummary']){
                    $objectName = "$objectName ($($entity.object.sharepointSiteSummary.siteWebUrl))"
                }
            }
            $startTimeUsecs = $lastRun.localBackupInfo.startTimeUsecs
            $entityStartTimeUsecs = $entity.localSnapshotInfo.snapshotInfo.startTimeUsecs
            $entityEndTimeUsecs = $entity.localSnapshotInfo.snapshotInfo.endTimeUsecs
            $durationSecs = [math]::Round(($entityEndTimeUsecs - $entityStartTimeUsecs) / 1000000,0)
            $status = $entity.localSnapshotInfo.snapshotInfo.status.Substring(1)
            if($status -eq 'Failed'){
                $message = $entity.localSnapshotInfo.failedAttempts[-1].message.replace("`n", " ")
            }elseif($status -eq 'Warning' -or $status -eq 'WaitingForNextAttempt'){
                $message = $entity.localSnapshotInfo.snapshotInfo.warnings[0].replace("`n", " ")
            }else{
                $message = ""
            }
            "    {0}" -f $objectName
            """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}""" -f $job.name, $job.environment.Substring(1), $objectName, (usecsToDate $startTimeUsecs), $status, $durationSecs, $message | Out-File -FilePath $outputfile -Append
        }
    }
}

"Output saved to $outputfile"
