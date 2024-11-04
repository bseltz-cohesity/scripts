### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',           # local or AD domain
    [Parameter(Mandatory = $True)][string]$viewName,  # name of view to create
    [Parameter(Mandatory = $True)][int]$quotaGiB,     # name of view to create
    [Parameter()][int]$alertThreshold = 85,  # percent of quota to alert
    [Parameter()][array]$principal,                   # list of users to grant full control
    [Parameter()][string]$principalList = ''          # list of users to grant read/write
)

# gather list of users to add to job
$usersToAdd = @()
foreach($u in $principal){
    $usersToAdd += $u
}
if ('' -ne $principalList){
    if(Test-Path -Path $principalList -PathType Leaf){
        $users = Get-Content $principalList
        foreach($u in $users){
            $usersToAdd += [string]$u
        }
    }else{
        Write-Warning "user list $principalList not found!"
        exit
    }
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$quotaBytes = $quotaGiB * (1024 * 1024 * 1024)

# find the view
$view = api get "views/$viewName"
if(!$view){
    Write-Host "View $viewName not found" -ForegroundColor Yellow
    exit
}

foreach($user in $usersToAdd){
    $domain, $domainuser = $user.split('\')
    $principal = api get "activeDirectory/principals?domain=$domain&includeComputers=true&search=$domainuser" | Where-Object fullName -eq $domainuser
    if(! $principal){
        write-host "$user not found" -ForegroundColor Yellow
    }else{
        $sid = $principal.sid
        $quotaParams = @{
            "viewName" = $view.name;
            "userQuotaPolicy" = @{
                "sid" = $sid;
                "quotaPolicy" = @{
                    "hardLimitBytes" = [int64]$quotaBytes;
                    "alertThresholdPercentage" = $alertThreshold
                }
            }
        }
        write-host "Setting $user quota to $quotaGiB GiB"
        $null = api post viewUserQuotas $quotaParams
    }
}
