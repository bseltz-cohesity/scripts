### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$resolution,
    [Parameter()][string]$alertType,
    [Parameter()][string]$severity
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get alerts
$alerts = api get alerts | Where-Object alertState -ne 'kResolved'

# show alerts
if($severity){
    $alerts = $alerts | Where-Object severity -eq $severity
}
if($alertType){
    $alerts = $alerts | Where-Object alertType -eq $alertType
}
$alerts | Format-Table -Property @{l='Latest Occurrence'; e={usecsToDate ($_.latestTimestampUsecs)}}, alertType, severity, @{l='Description'; e={$_.alertDocument.alertDescription}}

if($resolution){
    $alertResolution = @{
        "alertIdList" = @($alerts.id);
        "resolutionDetails" = @{
            "resolutionDetails" = $resolution;
            "resolutionSummary" = $resolution
        }
    }
    $null = api post alertResolutions $alertResolution
}
