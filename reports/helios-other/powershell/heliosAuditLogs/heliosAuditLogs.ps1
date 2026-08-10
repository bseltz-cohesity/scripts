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
    [Parameter()][int]$days = 7,
    [Parameter()][int]$maxRowsPerFile = 1000000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

if($maxRowsPerFile -lt 1){
    Write-Host "-maxRowsPerFile must be greater than 0"
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

function ConvertTo-JsonText {
    # serviceContext/details/previousRecord/newRecord can come back as already-serialized
    # JSON strings OR as nested objects/arrays (auto-parsed by ConvertFrom-Json). If we let
    # a nested object/array flow into the $csvValues comma-list untouched, PowerShell silently
    # unrolls (flattens) it into extra elements, which shifts every field after it into the
    # wrong column for that row -- this is what makes it look like a stray "null" (or any other
    # token) is kicking off a new record when the file is opened in Excel. Forcing everything
    # through ConvertTo-Json here guarantees a single, deterministic string per field.
    param($Value)
    if($null -eq $Value){ return $null }
    if($Value -is [string]){ return $Value }
    try {
        return ($Value | ConvertTo-Json -Depth 20 -Compress)
    } catch {
        return [string]$Value
    }
}

$excelMaxCellChars = 32000
$script:truncatedCellCount = 0

function ConvertTo-CsvField {
    param($Value)
    if($null -eq $Value){ return '""' }
    $s = [string]$Value
    $s = $s -replace "`r`n", ' ' -replace "`r", ' ' -replace "`n", ' '
    if($s.Length -gt $excelMaxCellChars){
        $charsCut = $s.Length - $excelMaxCellChars
        $marker = "...[TRUNCATED, $charsCut more chars -- exceeded Excel's 32767-char cell limit]"
        $s = $s.Substring(0, $excelMaxCellChars - $marker.Length) + $marker
        $script:truncatedCellCount += 1
    }
    $s = $s -replace '"', '""'
    return '"' + $s + '"'
}

$dateString = ($today).ToString('yyyy-MM-dd')
$baseFileName = "heliosAuditLogs-$dateString"
$csvHeaders = 'timestamp','ip','sourceType','originalTenantName','isImpersonation','tenantName','action','username','domain','tenantId','clusterName','entityName','clusterIdentifier','entityType','originalTenantId','serviceContext','details','previousRecord','newRecord'
$csvHeaderLine = ($csvHeaders | ForEach-Object { ConvertTo-CsvField $_ }) -join ','

# auto-split support: file part number is only appended once a second file is needed
$filePartNumber = 1
$rowsInCurrentFile = 0
$outputFiles = @()

function Get-OutFilePath {
    param([int]$PartNumber)
    if($PartNumber -eq 1){
        return Join-Path -Path $outFolder -ChildPath "$baseFileName.csv"
    } else {
        return Join-Path -Path $outFolder -ChildPath "$baseFileName-part$PartNumber.csv"
    }
}

function New-OutputFile {
    param([int]$PartNumber)
    $path = Get-OutFilePath -PartNumber $PartNumber
    $csvHeaderLine | Out-File -FilePath $path -Encoding utf8
    return $path
}

$outfile = New-OutputFile -PartNumber $filePartNumber
$outputFiles += $outfile

$count = 0
$foundLogs = 0
$thisStart = $uStart
$thisEnd = $uEnd
while($True){
    $logs = api get -mcmv2 "audit-logs?startTimeUsecs=$uStart&endTimeUsecs=$thisEnd&count=10000&actions=%2Caccept%2Cactivate%2Cadd%2Capply%2Cassign%2Ccancel%2Cclone%2Cclose%2Ccloudspin%2Cclusterexpand%2Ccreate%2Cdeactivate%2Cdelete%2Cdisjoin%2Cdownload%2Cimport%2Cinstall%2Cjoin%2Clogin%2Clogout%2Cmark%2Cmodify%2Cnotificationrule%2Coverwrite%2Cpause%2Crecover%2Crefresh%2Cregister%2Cmarkremoval%2Cremove%2Crename%2Crestart%2Cresume%2Crevert%2Crundiagnostics%2Crunnow%2Cschedule%2Cschedulereport%2Csearch%2Cstart%2Cstop%2Cunassign%2Cuninstall%2Cunregister%2Cupdate%2Cupgrade%2Cupload%2Cvalidate"
    $count = $logs.count
    # Write-Host "    $count"
    if($logs -and $logs.PSObject.Properties['auditLogs'] -and $logs.auditLogs -ne $null){
        $foundLogs += @($logs.auditLogs).Count
        Write-Host $foundLogs
        foreach($log in $logs.auditLogs){
            if($rowsInCurrentFile -ge $maxRowsPerFile){
                $filePartNumber += 1
                $outfile = New-OutputFile -PartNumber $filePartNumber
                $outputFiles += $outfile
                $rowsInCurrentFile = 0
            }
            $timeStamp = usecsToDate $log.timestampUsecs
            $serviceContextText = ConvertTo-JsonText $log.serviceContext
            $detailsText = ConvertTo-JsonText $log.details
            $previousRecordText = ConvertTo-JsonText $log.previousRecord
            $newRecordText = ConvertTo-JsonText $log.newRecord
            $csvValues = $timeStamp, $log.ip, $log.sourceType, $log.originalTenantName, $log.isImpersonation, $log.tenantName, $log.action, $log.username, $log.domain, $log.tenantId, $log.clusterName, $log.entityName, $log.clusterIdentifier, $log.entityType, $log.originalTenantId, $serviceContextText, $detailsText, $previousRecordText, $newRecordText
            (($csvValues | ForEach-Object { ConvertTo-CsvField $_ }) -join ',') | Out-File -FilePath $outfile -Append -Encoding utf8
            $rowsInCurrentFile += 1
            $lastTimeStamp = $log.timestampUsecs
        }
    }
    if(1 -gt $count){
        break
    }else{
        $thisEnd = $lastTimeStamp - 1000
        $count = 0
    }
}

if($outputFiles.Count -gt 1){
    Write-Host "`nOutput split across $($outputFiles.Count) files (max $maxRowsPerFile rows per file):"
    $outputFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
} else {
    Write-Host "`nOutput saved to $outfile`n"
}
