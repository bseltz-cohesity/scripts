# general params
$targetCluster = 'clustera'
$userName = 'admin'
$userDomain = 'local'
$viewList = '.\myviews.txt'

# using helios
# .\viewDR.ps1 -helios -targetCluster $targetCluster -username $userName -domain $userDomain -viewList $viewList -prepareForFailover
# using cluster direct
.\viewDR.ps1 -targetCluster $targetCluster -username $userName -domain $userDomain -viewList $viewList -prepareForFailover
# using mcm
# .\viewDR.ps1 -mcm $mcm -targetCluster $targetCluster -username $userName -domain $userDomain -viewList $viewList -prepareForFailover
