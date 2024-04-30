# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter(Mandatory = $True)][string]$csvFile
)

$csv = Import-Csv -Path $csvFile
if(! $csv){
    Write-Host "$csvFile not loaded" -ForegroundColor Yellow
    exit 1
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

$sources = api get -mcmv2 "data-protect/sources?regionIds=$regionList&environments=kPhysical"

foreach($source in $csv){
    $thisSource = $sources.sources | Where-Object {$_.name -eq $source.current}
    if($thisSource){
        Write-Host "Renaming $($source.current) -> $($source.new)"
        $renameParams = @{
            "environment" = $thisSource.environment;
            "connectionId" = $thisSource.sourceInfoList[0].registrationDetails.connectionId;
            "physicalParams" = @{
                "endpoint" = "$($source.new)";
                "physicalType" = "kHost";
                "hostType" = $thisSource.sourceInfoList[0].physicalSourceInfo.hostType
            }
        }
        $null = api put -mcmv2 "data-protect/sources/registrations/$($thisSource.sourceInfoList[0].registrationId)" $renameParams
    }else{
        Write-Host "$($source.current) not found" -ForegroundColor Yellow
    }
}
