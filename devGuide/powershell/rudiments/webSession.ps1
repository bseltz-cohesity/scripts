<#
This example shows the rudimentary process to authenticate to a Cohesity cluster using the UI login API.
Note that the this API requires the privilege to access to UI.
#>

# provide your information here
$username = 'admin'
$password = 'MyPassword!'
$domain = 'local'
$cluster = 'mycluster.mydomain.net'

# basic headers 
$HEADER = @{'accept' = 'application/json'; 
            'content-type' = 'application/json'}

# create a JSON payload with the credentials
$BODY = ConvertTo-Json @{'domain' = $domain; 
                         'username' = $username; 
                         'password' = $password}

# accessTokens URL
$URL = "https://$cluster/login"

# authenticate using the Invoke-RestMethod commandlet, with the URL, Headers and payload, and specify a session variable
$auth = Invoke-RestMethod -Method Post -Uri $URL -Header $HEADER -Body $BODY -SkipCertificateCheck -SessionVariable session

# now we can make authenticated API calls using the session variable ($sesion), for example, let's get the list of protection groups
$URL = "https://$cluster/irisservices/api/v1/public/protectionJobs"

$jobs = Invoke-RestMethod -Method Get -Uri $URL -Header $HEADER -SkipCertificateCheck -WebSession $session

$jobs | Format-Table
