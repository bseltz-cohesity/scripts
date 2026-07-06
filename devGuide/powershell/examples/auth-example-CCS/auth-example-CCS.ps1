# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'CCS',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter(Mandatory=$True)][string]$objectName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt

# get the list of configured regions for our CCS tenant
$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

# let's find an object (like a VM)
$objects = api get -v2 "data-protect/search/objects?searchString=$objectName&regionIds=$regionList"

# filter the results on the exact object name we wanted
$objects = $objects.objects | Where-Object {$_.name -eq $objectName}

# report if no object was found
if(@($objects).Count -eq 0){
    Write-Host "$objectName not found" -ForegroundColor Yellow
    exit
}

# for each object we found, let's display some information
foreach($object in $objects){
    foreach($objectProtectionInfo in $object.objectProtectionInfos){
        if($objectProtectionInfo.objectBackupConfiguration){
            Write-Host "$($object.name) [$($object.environment)] $($objectProtectionInfo.regionId) (protected)"
        }else{
            Write-Host "$($object.name) [$($object.environment)] $($objectProtectionInfo.regionId)"
        }
    }
}
