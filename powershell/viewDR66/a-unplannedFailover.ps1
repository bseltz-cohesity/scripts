# general params
$sourceCluster = 'clustera'
$targetCluster = 'clusterb'
$userName = 'myhelios@mydomain.net'
$userDomain = 'local'

# DFS params
$dfsNameSpace = '\\sa.corp.cohesity.com\HA'

# DNS params
$cname = 'nas'
$cnameDomain = 'sa.corp.cohesity.com'

# failover the views
# using helios
.\viewDR.ps1 -clusterName $targetCluster -username $userName -domain $userDomain -all -unplannedFailover
# using cluster direct
# .\viewDR.ps1 -vip $targetCluster -username $userName -domain $domainName -all -unplannedFailover

# toggle dfs folder targets and/or cnames and SPNs
if(Test-Path -Path migratedShares.txt -PathType Leaf){
    .\dfsFailover.ps1 -nameSpace $dfsNameSpace -shareList .\migratedShares.txt -disableTarget "\\$sourceCluster" -enableTarget "\\$targetCluster"
    .\cnameFailover.ps1 -cname $cname -oldHost $sourceCluster -newHost $targetCluster -domain $cnameDomain
}