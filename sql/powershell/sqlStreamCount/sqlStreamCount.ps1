# usage: ./sqlStreamCount.ps1 -vip mycluster -username myusername -domain mydomain.net

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local'            # local or AD domain
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get cluster name
$clusterName = (api get cluster).name

# output filename
$outFile = "sqlStreamCount-$clusterName-$((get-date).tostring('yyyy-MM-dd')).csv"

# get SQL sources
$sources = api get "protectionSources/registrationInfo?allUnderHierarchy=true&environments=kSQL"

# get VDI SQL jobs
$jobs = api get "protectionJobs?environments=kSQL&allUnderHierarchy=true&isDeleted=false&isActive=true" | `
    Where-Object { $_.environmentParameters.sqlParameters.backupType -eq 'kSqlNative' }

"`nCollecting Job Settings..."
$output = @()
foreach($job in $jobs | Sort-Object -Property name){
    foreach($sqlServer in $job.sourceSpecialParameters){
        $sqlSource = $sources.rootNodes | Where-Object { $_.rootNode.id -eq $sqlServer.sourceId }
        $output += New-Object psobject -Property @{
            'Job Name' = $job.name; 
            'Server Name' = $sqlSource.rootNode.name; 
            'Stream Count' = $job.environmentParameters.sqlParameters.numStreams
        }
    }
}

# output
$output | Select-Object -Property 'Job Name', 'Server Name', 'Stream Count'
$output | Select-Object -Property 'Job Name', 'Server Name', 'Stream Count'| Export-Csv -Path $(Join-Path -Path $PSScriptRoot -ChildPath $outFile) -NTI
"`nOutput Saved to $outFile"
