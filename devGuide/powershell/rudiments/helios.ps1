<#
This example shows the rudimentary process to authenticate through Helios to a Cohesity cluster using an API key.
#>

# provide your information here
$apikey = '12345678-abcd-1234-abcd-123456789012'
$cluster = 'myCluster' # we must use the short cluster name here (as registered in Helios)

# basic headers plus 'apiKey' header 
$HEADER = @{'accept' = 'application/json'; 
            'content-type' = 'application/json';
            'apiKey' = $apikey}

# let's get the list of Helios-connected clusters
$URL = 'https://helios.cohesity.com/mcm/clusters/connectionStatus'

$heliosClusters = Invoke-RestMethod -Method Get -Uri $URL -Header $HEADER -SkipCertificateCheck

# then let's get the cluster ID for our cluster
$clusterId = ($heliosClusters | Where-Object name -eq $cluster).clusterId 

# then add a 'clusterId' header with the cluster ID
$HEADER = @{'accept' = 'application/json'; 
            'content-type' = 'application/json';
            'apiKey' = $apikey;
            'clusterId' = $clusterId} # added the cluster ID

# now we can make API calls to the cluster through Helios, for example, let's get the list of protection groups
$URL = "https://helios.cohesity.com/irisservices/api/v1/public/protectionJobs"

$jobs = Invoke-RestMethod -Method Get -Uri $URL -Header $HEADER -SkipCertificateCheck

$jobs | Format-Table
