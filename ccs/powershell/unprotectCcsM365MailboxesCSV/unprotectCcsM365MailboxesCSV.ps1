# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter(Mandatory = $True)][string]$csvFile,
    [Parameter()][switch]$dbg,
    [Parameter()][switch]$deleteSnapshots
)

$objectsToAdd = Import-Csv -Path $csvFile # -Encoding utf8

if($objectsToAdd.Count -eq 0){
    Write-Host "No mailboxes specified" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if($dbg){
    enableCohesityAPIDebugger
}

if($deleteSnapshots){
    $delSnaps = $True
}else{
    $delSnaps = $false
}

# authenticate
apiauth -username $username

# find O365 source
Write-Host "Finding M365 Protection Source"
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365&excludeProtectionStats=true&regionIds=$region").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$script:nameIndex = @{}
$script:smtpIndex = @{}
$script:idIndex = @{}
$script:unprotectedIndex = @()
$script:protectedIndex = @()
$script:protectedCount = 0

function indexObject($obj){
    foreach($objectProtectionInfo in $obj.objectProtectionInfos | Where-Object {$_.regionId -eq $region -and $_.sourceId -eq $rootSourceId}){
        $script:nameIndex[$obj.name] = $objectProtectionInfo.objectId
        $script:idIndex["$($objectProtectionInfo.objectId)"] = $obj.name
        $script:smtpIndex[$obj.o365Params.primarySMTPAddress] = $objectProtectionInfo.objectId
        if($objectProtectionInfo.objectBackupConfiguration -and $objectProtectionInfo.objectBackupConfiguration -ne $null){
            $script:protectedCount += 1
            $script:protectedIndex = @($script:protectedIndex + $objectProtectionInfo.objectId)
        }else{
            $script:unprotectedIndex = @($script:unprotectedIndex + $objectProtectionInfo.objectId)
        }
    }
}

foreach($obj in $objectsToAdd){
    $objName = $obj.name
    $objSMTP = $obj.smtpAddress
    $objId = $null
    if($script:smtpIndex.ContainsKey($objSMTP)){
        $objId = $script:smtpIndex[$objSMTP]
    }else{
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kO365Exchange&regionIds=$region&sourceIds=$rootSourceId&count=999&searchString=$objName"
        $search.objects = $search.objects | Where-Object {$_.o365Params.primarySMTPAddress -eq $objSMTP}
        foreach($obj in $search.objects){
            indexObject($obj)
        }
        if(@($search.objects).Count -lt 1 -or $search.objects -eq $null){
            Write-Host "Mailbox $objName not found" -ForegroundColor Yellow
            continue
        }else{
            $objId = $script:smtpIndex[$objSMTP]
        }
    }
    if($objId -and $objId -in $script:protectedIndex){
        $unprotectParams = @{
            "action" = "UnProtect";
            "objectActionKey" = "kO365Exchange";
            "unProtectParams" = @{
                "objects" = @(
                    @{
                        "id" = $objId;
                        "deleteAllSnapshots" = $delSnaps;
                        "forceUnprotect" = $true
                    }
                )
            }
        }
        Write-Host "Unprotecting $objSMTP"
        $null = api post -v2 "data-protect/protected-objects/actions?regionIds=$region" $unprotectParams
    }elseif($objId -and $objId -notin $script:protectedIndex){
        Write-Host "Mailbox $objSMTP not protected" -ForegroundColor Magenta
    }else{
        Write-Host "Mailbox $objSMTP not found" -ForegroundColor Yellow
    }
}
