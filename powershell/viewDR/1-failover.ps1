# view failover settings
$sourceCluster = 'mysourcecluster'
$targetCluster = 'mytargetcluster'
$userName = 'myusername'
$domain = 'mydomain.net'
$metaDataPath = '\\my\unc\path'
$policyName = 'mypolicyname'

# DFS failover settings
$dfsNameSpace = '\\mydomain.net\myshare'
$sourceDFSPath = '\\mysourcecluster.mydomain.net'
$targetDFSPath = '\\mytargetcluster.mydomain.net'

# DNS failover settings
$cname = 'mycname'
$cnameDomain = 'mydomain.net'
$sourceArecord = 'mysourcecluster'
$targetArecord = 'mytargetcluster'

# clone the replicated view backups
.\viewDRclone.ps1 -vip $targetCluster -username $userName -domain $domain -viewList ./myviews.txt -inPath "$metaDataPath\$sourceCluster" -policyName $policyName
# toggle dfs folder targets
.\dfsFailover.ps1 -nameSpace $dfsNameSpace -shareList .\migratedShares.txt -disableTarget $sourceDFSPath -enableTarget $targetDFSPath
# toggle cnames and SPNs
.\cnameFailover.ps1 -cname $cname -oldHost $sourceArecord -newHost $targetArecord -domain $cnameDomain
# remove views from source
.\viewDRdelete.ps1 -vip $sourceCluster -username $userName -domain $domain -viewList ./myviews.txt -deleteSnapshots
