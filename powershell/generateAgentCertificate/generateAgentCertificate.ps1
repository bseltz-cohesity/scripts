# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$serverName,
    [Parameter()][string]$country = 'US',
    [Parameter()][string]$state = 'CA',
    [Parameter()][string]$city = 'SN',
    [Parameter()][string]$organization = 'Cohesity',
    [Parameter()][string]$organizationUnit = 'IT',
    [Parameter()][int64]$expiryDays = 365
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================


# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items)
}


$serverNames = @(gatherList -Param $serverName -Name 'server names' -Required $True)

# outfile
$outfileName = "server_cert-$($serverNames[0])"

$certreq = @{
    "organization" = $organization;
    "organizationUnit" = $organizationUnit;
    "countryCode" = $country;
    "state" = $state;
    "city" = $city;
    "keyType" = "RSA_4096";
    "commonName" = "Agent (gRPC server)";
    "sanList" = @(
        "Agent (gRPC server)"
    );
    "duration" = "$([int64]($expiryDays * 24))h"
}

foreach($server in $serverNames | Sort-Object -Unique){
    $certreq.sanList = @($certreq.sanList + $server)
}

"`n$($certreq | toJson)"

$newcert = api post -v2 "cert-manager/binary-cert" $certreq
$newcert | Out-File -FilePath $outfileName -Encoding ascii

"`nNew certificate saved to $outfileName`n"
