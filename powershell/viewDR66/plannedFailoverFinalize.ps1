# general params
$sourceCluster = 'clustera'
$targetCluster = 'clusterb'
$userName = 'admin'
$userDomain = 'local'

# DFS params
$dfsNameSpace = '\\sa.corp.cohesity.com\HA'

# DNS params
$cname = 'nas'
$cnameDomain = 'sa.corp.cohesity.com'

# using helios
# .\viewDR.ps1 -helios -targetCluster $targetCluster -username $userName -domain $userDomain -viewList .\myviews.txt -plannedFailover
# using cluster direct
.\viewDR.ps1 -targetCluster $targetCluster -username $userName -domain $userDomain -viewList .\myviews.txt -plannedFailover
# using mcm
# .\viewDR.ps1 -mcm $mcm -targetCluster $targetCluster -username $userName -domain $userDomain -viewList .\myviews.txt -plannedFailover

# toggle dfs folder targets and/or cnames and SPNs
if(Test-Path -Path migratedShares.txt -PathType Leaf){
    .\dfsFailover.ps1 -nameSpace $dfsNameSpace -shareList .\migratedShares.txt -disableTarget "\\$sourceCluster" -enableTarget "\\$targetCluster"
    .\cnameFailover.ps1 -cname $cname -oldHost $sourceCluster -newHost $targetCluster -domain $cnameDomain
}