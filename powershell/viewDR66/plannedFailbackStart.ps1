# general params
$targetCluster = 'clustera'
$userName = 'admin'
$userDomain = 'local'

# using helios
# .\viewDR.ps1 -helios -targetCluster $targetCluster -username $userName -domain $userDomain -viewList .\myviews.txt -prepareForFailover
# using cluster direct
.\viewDR.ps1 -targetCluster $targetCluster -username $userName -domain $userDomain -viewList .\myviews.txt -prepareForFailover
# using mcm
# .\viewDR.ps1 -mcm $mcm -targetCluster $targetCluster -username $userName -domain $userDomain -viewList .\myviews.txt -prepareForFailover
