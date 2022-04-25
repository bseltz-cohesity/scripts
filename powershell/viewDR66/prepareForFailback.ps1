# general params
$mcm = 'bseltz-mcm'
$sourceCluster = 'VE66b'
$targetCluster = 'VE66a'
$userName = 'admin'
$userDomain = 'local'
$policyName = 'replicate'

# using helios
# .\enableReplication -helios -targetCluster $targetCluster -sourceCluster $sourceCluster -username $userName -domain $userDomain -policyName $policyName -viewList .\myviews.txt
# using cluster direct
# .\enableReplication -targetCluster $targetCluster -sourceCluster $sourceCluster -username $userName -domain $userDomain -policyName $policyName -viewList .\myviews.txt
# using mcm
.\enableReplication -mcm $mcm -targetCluster $targetCluster -sourceCluster $sourceCluster -username $userName -domain $userDomain -policyName $policyName -viewList .\myviews.txt
