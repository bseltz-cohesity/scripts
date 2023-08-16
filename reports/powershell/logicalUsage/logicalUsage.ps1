### usage: ./logicalUsage.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] [ -days 90 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$days = 14,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB',
    [Parameter()][switch]$localOnly
)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$outFile = Join-Path -Path $PSScriptRoot -ChildPath "logicalUsage-$($cluster.name).csv"

$report = @{}

"Inspecting snapshots..."
foreach ($job in (api get protectionJobs?allUnderHierarchy=true)){
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
                    "{0}`t{1}`t{2}" -f (usecsToDate $run.backupRun.stats.startTimeUsecs), $sourcename, $source.stats.totalLogicalBackupSizeBytes
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
    $views = api get views?allUnderHierarchy=true
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

"`n{0,15}  {1,10}  {2}" -f ('Environment', "Size ($unit)", 'Name')
"{0,15}  {1,10}  {2}" -f ('===========', '=========', '====')
"Environment,Size($unit),Name" | Out-File -FilePath $outFile

$report.GetEnumerator() | Sort-Object -Property {$_.Value.size} -Descending | ForEach-Object {
    $item = $_
    $environment = $item.Value.environment
    $size = toUnits $item.Value.size
    $name = $item.Name
    "{0,15}  {1,10}  {2}" -f $environment, $size, $name
    "{0},""{1}"",{2}" -f $environment, $size, $name | Out-File -FilePath $outFile -Append
    $total += $item.Value.size
}
$total = toUnits $total
"`n    Total Logical Size: {0} $unit`n" -f $total
