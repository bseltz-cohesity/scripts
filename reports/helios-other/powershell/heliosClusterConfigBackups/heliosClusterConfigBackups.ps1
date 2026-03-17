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
    [Parameter()][int]$days = 30
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$midnight = Get-Date -Hour 0 -Minute 0
$midnightUsecs = dateToUsecs $midnight
$tonightUsecs = $midnightUsecs + 86399000000
$beforeUsecs = $midnightUsecs - ($days * 86400000000) + 86400000000

$outfile = $(Join-Path -Path $outFolder -ChildPath "heliosClusterConfigBackups.csv")
"""Job Name"",""Cluster Name"",""Start Time"",""Run Status"",""Error Message""" | Out-File -FilePath $outfile

$jobs = api get -mcmv2 cluster-config/export/jobs
$activities = api get -mcmv2 "cluster-config/activities?fromTimeUsecs=$beforeUsecs&toTimeUsecs=$tonightUsecs&excludeExportRunDetails=true"
$report = @()

foreach($activity in $activities.activities){
    $clusterName = $activity.exportParams.exportClusterIdentifier
    $thisCluster = (heliosClusters) | Where-Object {$clusterName -eq "$($_.clusterId):$($_.clusterIncarnationId)"}
    if($thisCluster){
        $clusterName = $thisCluster.name
    }
    $jobName = $activity.exportParams.configExportJobId
    $job = $jobs.configExportJobs | Where-Object {$_.configExportJobId -eq $activity.exportParams.configExportJobId}
    if($job){
        $jobName = $job.name
    }
    Write-Host "$($clusterName) ($(usecsToDate $activity.exportParams.startTimeUsecs)) $($activity.exportParams.configExportRunStatus)"
    """$($jobName)"",""$($clusterName)"",""$(usecsToDate $activity.exportParams.startTimeUsecs)"",""$($activity.exportParams.configExportRunStatus)"",""$($activity.exportParams.errorDetails.message)""" | Out-File -FilePath $outfile -Append
}

"`nOutput saved to $outfile`n"
