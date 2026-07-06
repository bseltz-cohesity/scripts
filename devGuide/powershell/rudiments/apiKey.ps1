<#
This example shows the rudimentary process to authenticate to a Cohesity cluster using an API key.
#>

# provide your information here
$apikey = '12345678-abcd-1234-abcd-123456789012'
$cluster = 'mycluster.mydomain.net'

# basic headers plus 'apiKey' header 
$HEADER = @{'accept' = 'application/json'; 
            'content-type' = 'application/json';
            'apiKey' = $apikey}

# now we can make authenticated API calls, for example, let's get the list of protection groups
$URL = "https://$cluster/irisservices/api/v1/public/protectionJobs"

$jobs = Invoke-RestMethod -Method Get -Uri $URL -Header $HEADER -SkipCertificateCheck

$jobs | Format-Table
