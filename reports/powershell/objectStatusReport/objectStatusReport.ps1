### Usage: ./summaryReport.ps1 -vip mycluster -username myuser -domain mydomain.net

### process commandline arguments
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
    [Parameter()][switch]$yesterdayOnly,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB','MB','GB','TB')][string]$unit = 'MiB'
)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024; 'MB' = 1000 * 1000; 'GB' = 1000 * 1000 * 1000; 'TB' = 1000 * 1000 * 1000}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
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
    exit 1
}

# date range
$now = Get-Date
$midnight = Get-Date -Hour 0 -Minute 0 -Second 0
$yesterday = $midnight.AddDays(-1)
$nowUsecs = dateToUsecs $now
$weekAgoUsecs = timeAgo 1 week
$midnightUsecs = dateToUsecs $midnight
$yesterdayUsecs = dateToUsecs $yesterday
if($yesterdayOnly){
    $endTimeUsecs = $midnightUsecs
    $startTimeUsecs = $yesterdayUsecs
}else{
    $endTimeUsecs = $nowUsecs
    $startTimeUsecs = $weekAgoUsecs
}

"saving summary report to report.csv..."
"Protection Object Type,Protection Object Name,Registered Source Name,Protection Job Name,Num Snapshots,Last Run Status,Schedule Type,Last Run Start Time,End Time,First Successful Snapshot,First Failed Snapshot,Latest Successful Snapshot,Latest Failed Snapshot,Num Errors,Data Read ($unit),Logical Protected ($unit),Organization Names" | Out-File -FilePath 'report.csv'
$report = api get "reports/protectionSourcesJobsSummary?startTimeUsecs=$startTimeUsecs&endTimeUsecs=$endTimeUsecs"
foreach($o in $report.protectionSourcesJobsSummary){
    $firstSuccessful = ''
    if($o.PSObject.Properties['firstSuccessfulRunTimeUsecs']){
        $firstSuccessful = usecsToDate $o.firstSuccessfulRunTimeUsecs
    }
    $firstFailed = ''
    if($o.PSObject.Properties['firstFailedRunTimeUsecs']){
        $firstFailed = usecsToDate $o.firstFailedRunTimeUsecs
    }
    $lastSuccessful = ''
    if($o.PSObject.Properties['lastSuccessfulRunTimeUsecs']){
        $lastSuccessful = usecsToDate $o.lastSuccessfulRunTimeUsecs
    }
    $lastFailed = ''
    if($o.PSObject.Properties['lastFailedRunTimeUsecs']){
        $lastFailed = usecsToDate $o.lastFailedRunTimeUsecs
    }
    $dateRead = ''
    if($o.PSObject.Properties['numDataReadBytes']){
        $dateRead = toUnits $o.numDataReadBytes
    }
    $logical = ''
    if($o.PSObject.Properties['numLogicalBytesProtected']){
        $logical = toUnits $o.numLogicalBytesProtected
    }
    $tenants = ''
    if($o.PSObject.Properties['tenants']){
        $tenants = $o.tenants.name -join ', '
    }

    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}"",""{12}"",""{13}"",""{14}"",""{15}"",""{16}""" -f $o.protectionSource.environment.subString(1),
                                                                                                                                                        $o.protectionSource.name,
                                                                                                                                                        $o.registeredSource,
                                                                                                                                                        $o.jobName,
                                                                                                                                                        $o.numSnapshots,
                                                                                                                                                        $o.lastRunStatus.subString(1),
                                                                                                                                                        $o.lastRunType.subString(1),
                                                                                                                                                        (usecsToDate $o.lastRunStartTimeUsecs),
                                                                                                                                                        (usecsToDate $o.lastRunEndTimeUsecs),
                                                                                                                                                        $firstSuccessful,
                                                                                                                                                        $firstFailed,
                                                                                                                                                        $lastSuccessful,
                                                                                                                                                        $lastFailed,
                                                                                                                                                        $o.numErrors,
                                                                                                                                                        $dateRead,
                                                                                                                                                        $logical,
                                                                                                                                                        $tenants | Out-File -FilePath 'report.csv' -Append



}
