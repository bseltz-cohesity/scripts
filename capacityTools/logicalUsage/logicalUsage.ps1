### usage: ./logicalUsage.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] [ -days 90 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$days = 90,
    [Parameter()][switch]$localOnly
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$outFile = Join-Path -Path $PSScriptRoot -ChildPath "logicalUsage-$($cluster.name).csv"

$report = @{}

"Inspecting snapshots..."
foreach ($job in (api get protectionJobs)){
    if(!($localOnly -and $job.IsActive -eq $False)){
        $runs = api get protectionRuns?jobId=$($job.id)`&numRuns=99999`&excludeNonRestoreableRuns=true`&runTypes=kFull`&runTypes=kRegular`&startTimeUsecs=$(timeAgo $days days)
        foreach ($run in $runs){
            if ($run.backupRun.snapshotsDeleted -eq $false) {
                foreach($source in $run.backupRun.sourceBackupStatus){
                    $sourcename = $source.source.name
                    if($sourcename -notin $report.Keys){
                        $report[$sourcename] = @{}
                        $report[$sourcename]['size'] = 0
                        $report[$sourcename]['environment'] = $source.source.environment
                    }
                    if($source.stats.totalLogicalBackupSizeBytes -gt $report[$sourcename]['size']){
                        $report[$sourcename]['size'] = $source.stats.totalLogicalBackupSizeBytes
                    }
                }
            }
        }
    }
}                                                                                           

"Inspecting Views..."
if($localOnly){
    $views = api get views
}else{
    $views = api get views?includeInactive=true
}
foreach($view in $views.views){
    $viewname = $view.name
    if($view.name -notin $report.Keys){
        $report[$viewname] = @{}
        $report[$viewname]['size'] = $view.logicalUsageBytes
        $report[$viewname]['environment'] = 'kView'
    }
}

$total = 0

"`n{0,15}  {1,10:n0}  {2}" -f ('Environment', 'Size (GB)', 'Name')
"{0,15}  {1,10:n0}  {2}" -f ('===========', '=========', '====')
"Environment,Size(GB),Name" | Out-File -FilePath $outFile

$report.GetEnumerator() | Sort-Object -Property {$_.Value.size} -Descending | ForEach-Object {
    "{0,15}  {1,10:n0}  {2}" -f ($_.Value.environment, [math]::Round(($_.Value.size/(1024*1024*1024)),2), $_.Name)
    "{0},{1},{2}" -f ($_.Value.environment, [math]::Round(($_.Value.size/(1024*1024*1024)),2), $_.Name) | Out-File -FilePath $outFile -Append
    $total += $_.Value.size
}
"`n    Total Logical Size: {0:n0} GB`n" -f ($total/(1024*1024*1024))
