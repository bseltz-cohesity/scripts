# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$region,
    [Parameter()][string]$password,
    [Parameter()][array]$sourceName,
    [Parameter()][string]$sourceList,
    [Parameter()][ValidateSet('kNfs3','kNfs4_1','kCifs1')][string]$mode,
    [Parameter()][switch]$update,
    [Parameter()][string]$smbUser,
    [Parameter()][string]$smbPassword
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# gather required credentials
if($update){
    if(!$smbUser -or !$smbPassword){
        Write-Host "`nPrompting for required SMB credentials:" -ForegroundColor Yellow
        if(!$smbUser){
            $smbUser = Read-Host -Prompt "        SMB Username"
        }
        if(!$smbPassword){
            $confirmPassword = '1'
            $smbPassword = '2'
            while($confirmPassword -ne $smbPassword){
                $secureString = Read-Host -Prompt "        SMB Password" -AsSecureString
                $smbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
                $secureString = Read-Host -Prompt "Confirm SMB Password" -AsSecureString
                $confirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
            }
        }
        Write-Host ''
    }
}

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
    return ($items | Sort-Object -Unique)
}

$sourceNames = @(gatherList -Param $sourceName -FilePath $sourceList -Name 'Generic NAS sources' -Required $false)

Write-Host "Gathering tenant info..."
$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

if($region){
    $regionList = ($regions.tenantRegionInfoList.regionId | Where-Object {$_ -eq $region})
}

# find registered generic NAS sources
Write-Host "Gathering registered NAS sources..."
$sources = api get -mcmv2 "data-protect/sources?regionIds=$regionList&environments=kGenericNas"
$nasSources = @($sources.sources | Where-Object {$_.environment -eq 'kGenericNas'})

# filter on source name
if($sourceNames.Count -gt 0){
    $nasSources = @($nasSources | Where-Object {$_.name -in $sourceNames})
    $notFound = $sourceNames | Where-Object {$_ -notin $nasSources.name}
    # report not found sources
    $notFound | Sort-Object | ForEach-Object{
        Write-Host "$_ not found" -ForegroundColor Yellow
    }
}

# get registration details for each source (mount mode)
$nasInfo = @()
foreach($nasSource in ($nasSources | Sort-Object -Property name)){
    foreach($sourceInfo in $nasSource.sourceInfoList){
        $registrationId = $sourceInfo.registrationId
        $registration = $null
        if($registrationId){
            $registration = api get -mcmv2 "data-protect/sources/registrations/$registrationId"
        }
        $nasInfo += [pscustomobject]@{
            name = $nasSource.name
            registrationId = $registrationId
            regionId = $sourceInfo.regionId
            mountPoint = $registration.genericNasParams.mountPoint
            mode = $registration.genericNasParams.mode
            description = $registration.genericNasParams.description
            currentUser = $registration.genericNasParams.smbMountCredentials.username
            registration = $registration
        }
    }
}

# filter on mount mode
if($mode){
    $nasInfo = @($nasInfo | Where-Object {$_.mode -eq $mode})
}

# if no sources were specified, operate on all sources currently using smbUser
if($sourceNames.Count -eq 0 -and $smbUser){
    $nasInfo = @($nasInfo | Where-Object {$_.currentUser -eq $smbUser})
    if($nasInfo.Count -eq 0){
        Write-Host "No Generic NAS sources found using SMB user $smbUser" -ForegroundColor Yellow
    }
}

if($update){
    foreach($nas in $nasInfo){
        if($nas.mode -ne 'kCifs1'){
            Write-Host "Skipping $($nas.name) (mode $($nas.mode) does not use credentials)" -ForegroundColor Yellow
            continue
        }
        if(!$nas.registrationId){
            Write-Host "Skipping $($nas.name) (no registration id found)" -ForegroundColor Yellow
            continue
        }
        $registrationParams = @{
            "environment" = "kGenericNas";
            "genericNasParams" = @{
                "mountPoint" = $nas.mountPoint;
                "mode" = $nas.mode;
                "skipValidation" = $false;
                "smbMountCredentials" = @{
                    "username" = $smbUser;
                    "password" = $smbPassword
                }
            }
        }
        if($nas.description){
            $registrationParams.genericNasParams['description'] = $nas.description
        }
        if($nas.registration.genericNasParams.throttlingConfig){
            $registrationParams.genericNasParams['throttlingConfig'] = $nas.registration.genericNasParams.throttlingConfig
        }
        if($nas.registration.connectorGroupId){
            $registrationParams['connectorGroupId'] = $nas.registration.connectorGroupId
        }
        Write-Host "Updating $($nas.name)"
        $result = api put -mcmv2 "data-protect/sources/registrations/$($nas.registrationId)" $registrationParams
    }
}else{
    $outfileName = "genericnas-sources.csv"
    """Mount Point"",""Region"",""Mode"",""SMB User""" | Out-File -FilePath $outfileName
    # report found sources
    $nasInfo | Format-Table -Property @{label="Mount Point"; expression={$_.mountPoint}}, @{label="Region"; expression={$_.regionId}}, @{label="Mode"; expression={$_.mode}}, @{label="SMB User"; expression={$_.currentUser}}
    $nasInfo | ForEach-Object{
        """{0}"",""{1}"",""{2}"",""{3}""" -f $_.mountPoint, $_.regionId, $_.mode, $_.currentUser | Out-File -FilePath $outfileName -Append
    }
    "Generic NAS source list saved to $outfileName`n"
}
