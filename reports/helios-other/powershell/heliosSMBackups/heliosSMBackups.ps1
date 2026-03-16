# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$outFolder = '.',
    [Parameter()][switch]$exportConfig,
    [Parameter()][switch]$hideSecretKey,
    [Parameter()][int]$pageSize = 100
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -passwd $password -heliosAuthentication $True -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# $dateString = (get-date).ToString('yyyy-MM-dd')
$outfile = $(Join-Path -Path $outFolder -ChildPath "heliosSMBackups-$vip.csv")
"""Start Time"",""End Time"",""Duration (Seconds)"",""Expiry Date"",""Location"",""Status"",""S3 Host"",""S3 Bucket""" | Out-File -FilePath $outfile
$configFile = $(Join-Path -Path $outFolder -ChildPath "heliosSMBackupConfig-$vip.txt")

$backups = api get -mcmv2 "backup-mgmt/backups?pageSize=$pageSize&page=1"
$config = api get -mcmv2 "backup-mgmt/backups/config"
$retentionDays = $config.retentionConfig.days

"`nBackups:`n"
foreach($backup in $backups.backupStatuses){
    $startTime = usecsToDate ($backup.startTimeMsecs * 1000)
    $expiryDate = usecsToDate (($backup.startTimeMsecs + ($retentionDays * 86400000)) * 1000)
    $endTime = ''
    $duration = ''
    if($backup.PSObject.Properties['endTimeMsecs']){
        $endTime = usecsToDate ($backup.endTimeMsecs * 1000)
        $duration = [math]::Round(($backup.endTimeMsecs - $backup.startTimeMsecs)/1000)
    }
    "$($startTime) ($($backup.status))"
    """$startTime"",""$endTime"",""$duration"",""$expiryDate"",""$($backup.backupLocation)"",""$($backup.status)"",""$($backup.s3Host)"",""$($backup.s3Bucket)""" | Out-File -FilePath $outfile -Append
}

"`nBackup report saved to $outfile`n"

if($exportConfig){
    "Exported config to $configFile`n"
    
    "host: $($config.s3Config.host)" | Out-File -FilePath $configFile
    "bucket: $($config.s3Config.bucket)" | Out-File -FilePath $configFile -Append
    "accessKey: $($config.s3Config.accessKey)" | Out-File -FilePath $configFile -Append
    if(!$hideSecretKey){
        "secretKey: $($config.s3Config.secretKey)" | Out-File -FilePath $configFile -Append
    }
    "backupFolder: $($config.s3Config.backupFolder)" | Out-File -FilePath $configFile -Append
    "retention: $retentionDays days" | Out-File -FilePath $configFile -Append
}
