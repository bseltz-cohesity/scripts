# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$outFolder = '.',
    [Parameter()][string]$startDate = '',
    [Parameter()][string]$endDate = '',
    [Parameter()][switch]$thisCalendarMonth,
    [Parameter()][switch]$lastCalendarMonth,
    [Parameter()][int]$days = 7
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# Date ranges
$today = Get-Date
if($startDate -ne '' -and $endDate -ne ''){ $uStart = dateToUsecs $startDate; $uEnd = dateToUsecs $endDate }
elseif($thisCalendarMonth){ $uStart = dateToUsecs ($today.Date.AddDays(-($today.Day - 1))); $uEnd = dateToUsecs $today }
elseif($lastCalendarMonth){
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.Day - 1)).AddMonths(-1))
    $uEnd = dateToUsecs ($today.Date.AddDays(-($today.Day - 1)).AddSeconds(-1))
} else {
    $uStart = timeAgo $days 'days'; $uEnd = dateToUsecs $today
}

function ConvertTo-CsvField {
    param($Value)
    if($null -eq $Value){ return '""' }
    $s = [string]$Value
    $s = $s -replace '"', '""'
    return '"' + $s + '"'
}

$dateString = ($today).ToString('yyyy-MM-dd')
$outfile = $(Join-Path -Path $outFolder -ChildPath "heliosAuditLogs-$dateString.csv")
$csvHeaders = 'timestamp','ip','sourceType','originalTenantName','isImpersonation','tenantName','action','username','domain','tenantId','clusterName','entityName','clusterIdentifier','entityType','originalTenantId','serviceContext','details','previousRecord','newRecord'
(($csvHeaders | ForEach-Object { ConvertTo-CsvField $_ }) -join ',') | Out-File -FilePath $outfile -Encoding utf8
$count = 0
$foundLogs = 0
$thisStart = $uStart
$thisEnd = $uEnd
while($True){
    $logs = api get -mcmv2 "audit-logs?startTimeUsecs=$uStart&endTimeUsecs=$thisEnd&count=10000"
    if($count -eq 0 -and $logs.count -gt 0){
        $count = $logs.count
    }
    if($logs -and $logs.PSObject.Properties['auditLogs'] -and $logs.auditLogs -ne $null){
        $foundLogs += @($logs.auditLogs).Count
        Write-Host $foundLogs
        foreach($log in $logs.auditLogs){
            $timeStamp = usecsToDate $log.timestampUsecs
            $csvValues = $timeStamp, $log.ip, $log.sourceType, $log.originalTenantName, $log.isImpersonation, $log.tenantName, $log.action, $log.username, $log.domain, $log.tenantId, $log.clusterName, $log.entityName, $log.clusterIdentifier, $log.entityType, $log.originalTenantId, $log.serviceContext, $log.details, $log.previousRecord, $log.newRecord
            (($csvValues | ForEach-Object { ConvertTo-CsvField $_ }) -join ',') | Out-File -FilePath $outfile -Append -Encoding utf8
            $lastTimeStamp = $log.timestampUsecs
        }
    }
    if($foundLogs -ge $count){
        break
    }else{
        $thisEnd = $lastTimeStamp
        $count = 0
    }
}

Write-Host "`nOutput saved to $outfile`n"