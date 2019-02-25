### Global Settings
$daysToKeep = 5
$daysToKeepFinalBackup = 365
$startTime = '22:00'
$vmList = './rack1-vmlist.txt'

### Local Setup Info
$localClusterName = 'myLocalCluster'
$localVip = '192.168.1.198'
$localUsername = 'admin'
$localDomain = 'local'
$localStorageDomain = 'DefaultStorageDomain'

$localJobName = 'LocalToRack1'
$localPolicyName = 'LocalToRack1'

$localVCenter = 'myvCenter.mydomain'

### Remote Rack Info
$remoteClusterName = 'Rack1VE'
$remoteVip = '192.168.1.199'
$remoteUsername = 'admin'
$remoteDomain = 'local'
$remoteStorageDomain = 'DefaultStorageDomain'

$remoteJobName = 'Rack1toLocal'
$remotePolicyName = 'Rack1toLocal'

$remoteVCenter = 'myRackvCenter.mydomain.net'
$remoteDatastore = 'datastore1'
$remoteNetwork = 'VM Network'
$remoteResourcePool = 'Test' #optional
$remoteVMFolder = 'Test' #optional
