# general params
$sourceCluster = 'clusterb'
$targetCluster = 'clustera'
$userName = 'admin'
$userDomain = 'local'
$policyName = 'replicate'
$viewList = '.\myviews.txt'

# using helios
# .\enableReplication -helios -targetCluster $targetCluster -sourceCluster $sourceCluster -username $userName -domain $userDomain -policyName $policyName -viewList $viewList
# using cluster direct
.\enableReplication -targetCluster $targetCluster -sourceCluster $sourceCluster -username $userName -domain $userDomain -policyName $policyName -viewList $viewList
# using mcm
# .\enableReplication -mcm $mcm -targetCluster $targetCluster -sourceCluster $sourceCluster -username $userName -domain $userDomain -policyName $policyName -viewList $viewList
