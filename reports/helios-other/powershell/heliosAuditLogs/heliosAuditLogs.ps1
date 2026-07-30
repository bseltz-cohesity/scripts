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
    [Parameter()][int]$days = 7,
    [Parameter()][ValidateRange(100, 10000)][int]$pageSize = 1000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfile = $(Join-Path -Path $outFolder -ChildPath "heliosAuditLogs-$dateString.csv")
"""timestamp"",""ip"",""sourceType"",""originalTenantName"",""isImpersonation"",""tenantName"",""action"",""username"",""domain"",""tenantId"",""clusterName"",""entityName"",""clusterIdentifier"",""entityType"",""originalTenantId"",""serviceContext"",""details"",""previousRecord"",""newRecord""" | Out-File -FilePath $outfile
$startIndex = 0
$count = 0
$foundLogs = 0
while($True){
    $logs = api get -mcmv2 "audit-logs?startTimeUsecs=$(timeAgo $days days)&count=$pageSize&startIndex=$startIndex"
    if($count -eq 0 -and $logs.count -gt 0){
        $count = $logs.count
    }
    if($logs -and $logs.PSObject.Properties['auditLogs'] -and $logs.auditLogs -ne $null){
        $foundLogs += @($logs.auditLogs).Count
        Write-Host $foundLogs
        foreach($log in $logs.auditLogs){
            $timeStamp = usecsToDate $log.timestampUsecs
            if($log.PSObject.Properties['previousRecord']){
                $log.previousRecord = $log.previousRecord -replace '\"', "'" -replace ",", ';' -replace "`n", " "
            }
            if($log.PSObject.Properties['newRecord']){
                $log.newRecord = $log.newRecord -replace '\"', "'" -replace ",", ';' -replace "`n", " "
            }
            $log.details = $log.details -replace '\"', "'" -replace ",", ';' -replace "`n", " " -replace "\n", " "
            """$timeStamp"",""$($log.ip)"",""$($log.sourceType)"",""$($log.originalTenantName)"",""$($log.isImpersonation)"",""$($log.tenantName)"",""$($log.action)"",""$($log.username)"",""$($log.domain)"",""$($log.tenantId)"",""$($log.clusterName)"",""$($log.entityName)"",""$($log.clusterIdentifier)"",""$($log.entityType)"",""$($log.originalTenantId)"",""$($log.serviceContext)"",""$($log.details)"",""$($log.previousRecord)"",""$($log.newRecord)""" | Out-File -FilePath $outfile -append
        }
    }
    if($foundLogs -ge $count){
        break
    }else{
        $startIndex += $pageSize
    }
}

Write-Host "`nOutput saved to $outfile`n"