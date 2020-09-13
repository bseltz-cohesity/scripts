### usage:
# .\netapp7ImportNFS.ps1 -vip mycluster `
#                        -username myusername `
#                        -domain mydomain.net `
#                        -controllerName mynetapp.mydomain.net `
#                        -exportPaths /vol/vol1, /volvol2 `
#                        -viewPrefix ntap-

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the Cohesity cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$controllerName, # name of the Netapp protection source
    [Parameter()][array]$exportPaths, # name(s) of volumes(s) to recover
    [Parameter()][string]$exportPathList = $null, # file list of volumes to recover
    [Parameter()][string]$viewPrefix = '', # prefix to apply to volume-level views
    [Parameter()][switch]$allExports
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to Cohesity cluster
apiauth -vip $vip -username $username -domain $domain

# gather list of volumes to recover
$exports = @()
foreach($e in $exportPaths){
    $exports += $e
}
if ($exportPathList){
    if(Test-Path -Path $exportPathList -PathType Leaf){
        $elist = Get-Content $exportPathList
        foreach($e in $elist){
            $exportss += $e
        }
    }else{
        Write-Warning "Export path list $exportPathList not found!"
        exit 1
    }
}

# get import file
$exportsfile = "$controllerName-exports.json"
if(Test-Path -Path $exportsfile -PathType Leaf){
    $netappExports = Get-Content -Path $exportsfile | ConvertFrom-Json
}else{
    Write-Host "Export file $exportsfile not found!" -ForegroundColor Yellow
    exit 1
}

$recoveredVolumes = @()
$views = api get views

# function to find latest snapshot
function findSnapshot($controllerName, $exportPath){
    $volumeName = "$($controllerName):$($exportPath)"
    $encodedVolumeName = [System.Web.HttpUtility]::UrlEncode($volumeName)
    $searchResult = api get "/searchvms?entityTypes=kGenericNas&vmName=$encodedVolumeName"
    $searchResult = $searchResult.vms | Where-Object {$_.vmDocument.objectName -eq $volumeName}
    if(! $searchResult){
        return $null
    }
    $searchResult = ($searchResult | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]
    return $searchResult.vmDocument
}

foreach($export in $netappExports){
    $exportPath = $export.Pathname
    if($exportPath -in $exports -or $allExports){
        $newViewName = "$viewPrefix$($exportPath.TrimStart('/').TrimStart('vol').TrimStart('/').replace('/','-'))"
        $existingView = $views.views | Where-Object name -eq $newViewName
        if(!$existingView){
            # get latest snapshot
            $snapshot = findSnapshot $controllerName $exportPath
            if($snapshot){
                # restore to a view
                $restoreParams = @{
                    "name"                  = "Recover-NetApp_$newViewName";
                    "objects"               = @(
                        @{
                            "jobId"              = $snapshot.objectId.jobId;
                            "jobUid"             = @{
                                "clusterId"            = $snapshot.objectId.jobUid.clusterId;
                                "clusterIncarnationId" = $snapshot.objectId.jobUid.clusterIncarnationId;
                                "id"                   = $snapshot.objectId.jobUid.objectId
                            };
                            "jobRunId"           = $snapshot.versions[0].instanceId.jobInstanceId;
                            "startedTimeUsecs"   = $snapshot.versions[0].instanceId.jobStartTimeUsecs;
                            "protectionSourceId" = $snapshot.objectId.entity.id
                        }
                    );
                    "type"                  = "kMountFileVolume";
                    "viewName"              = $newViewName;
                    "restoreViewParameters" = @{
                        "qos" = @{
                            "principalName" = "TestAndDev High"
                        }
                    }
                }
                write-host "    Migrating $($controllerName):$($exportPath) to $newViewName" -ForegroundColor Green
                $null = api post restore/recover $restoreParams
            }else{
                # mount not backed up
                write-host "    $($controllerName):$($exportPath) not backed up" -ForegroundColor Magenta
            }
            $recoveredVolumes += @{'viewName' = $newViewName; 'exportPath' = $exportPath;}
        }
    }
}

"Updating View Settings..."
Start-Sleep -Seconds 2

# function to convert cidr to netmask
function netbitsToDDN($netBits){
    $maskBits = '1' * $netBits + '0' * (32 - $netBits)
    $octet1 = [convert]::ToInt32($maskBits.Substring(0,8),2)
    $octet2 = [convert]::ToInt32($maskBits.Substring(8,8),2)
    $octet3 = [convert]::ToInt32($maskBits.Substring(16,8),2)
    $octet4 = [convert]::ToInt32($maskBits.Substring(24,8),2)
    return "$octet1.$octet2.$octet3.$octet4"
}

# function to create new whilelist entry
function newWhiteListEntry($cidr, $nfsAccess, $nfsRootSquash){
    $ip, $netbits = $cidr -split '/'
    if(!$netbits){
        $netbits = '32'
    }
    $maskDDN = netbitsToDDN $netbits
    $whitelistEntry = @{
        "nfsAccess" = $nfsAccess;
        "nfsRootSquash" = $nfsRootSquash;
        "ip"            = $ip;
        "netmaskIp4"    = $maskDDN
    }
    return $whitelistEntry
}

# set protocol and whitelist of migrated views
$views = api get views

foreach($volume in $recoveredVolumes){
    $exportPath = $volume.exportPath
    $newViewName = $volume.viewName
    $view = $views.views | Where-Object name -eq $newViewName
    if($view){
        $view.protocolAccess = 'kNFSOnly'
        if(! $view.PSObject.Properties['subnetWhiteList']){
            $view | Add-Member -MemberType NoteProperty -Name subnetWhiteList -Value @()
        }
        $netappExport = $netappExports | Where-Object Pathname -eq $exportPath
        foreach($secRule in $netappExport.SecurityRules){
            $nfsRootSquash = $secRule.NosuidSpecified
            foreach($entry in $secRule.ReadOnly){
                $view.subnetWhiteList += newWhiteListEntry $entry.Name 'kReadOnly' $nfsRootSquash
            }
            foreach($entry in $secRule.ReadWrite){
                $view.subnetWhiteList += newWhiteListEntry $entry.Name 'kReadWrite' $nfsRootSquash
            }
            foreach($entry in $secRule.Root){
                $view.subnetWhiteList += newWhiteListEntry $entry.Name 'kReadWrite' $false
            }
        }
        $null = api put views $view
    }
}
