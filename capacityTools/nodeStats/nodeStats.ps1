# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "nodeStats-$($cluster.name)-$dateString.csv"

# headings
"Node ID, Model, TiB Used, Pct Used" | Out-File -FilePath $outfileName

$nodes = api get nodes?fetchStats=true


foreach($node in $nodes){
    $used = $node.stats.usagePerfStats.totalPhysicalUsageBytes | %{ $_/(1024*1024*1024*1024)}
    $pctUsed = 100 * $node.stats.usagePerfStats.totalPhysicalUsageBytes / $node.stats.usagePerfStats.physicalCapacityBytes
    """{0}"",""{1}"",""{2:n2}"",""{3:n1}""" -f $node.id, $node.productModel, $used, $pctUsed
}

"`nOutput saved to $outfilename`n"
