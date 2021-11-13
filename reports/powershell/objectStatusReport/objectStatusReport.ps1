### Usage: ./summaryReport.ps1 -vip mycluster -username myuser -domain mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

"saving summary report to report.csv..."
api get reports/protectionSourcesJobsSummary?outputFormat=csv | Out-File report.csv
