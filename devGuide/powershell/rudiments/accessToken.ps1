<#
This example shows the rudimentary process to authenticate to a Cohesity cluster using the v1 accessTokens API.
Note that the accessTokens API is often disabled in recent versions of Cohesity, 
in which case you can use the v2 users/sessions API instead.
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
$URL = "https://$cluster/irisservices/api/v1/public/accessTokens"

# authenticate using the Invoke-RestMethod commandlet, with the URL, Headers and payload
$auth = Invoke-RestMethod -Method Post -Uri $URL -Header $HEADER -Body $BODY -SkipCertificateCheck

# add an 'authorization' header with the returned tokenType and accessToken
$HEADER = @{'accept' = 'application/json'; 
            'content-type' = 'application/json'; 
            'authorization' = $auth.tokenType + ' ' + $auth.accessToken}

# now we can make authenticated API calls, for example, let's get the list of protection groups
$URL = "https://$cluster/irisservices/api/v1/public/protectionJobs"

$jobs = Invoke-RestMethod -Method Get -Uri $URL -Header $HEADER -SkipCertificateCheck

$jobs | Format-Table
