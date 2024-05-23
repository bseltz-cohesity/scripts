### usage: ./viewDRclone.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -viewName 'My View' [ -newName 'Cloned-View' ] -inPath \\myserver\mypath

### process commandline arguments
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
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter(Mandatory = $True)][string]$suffix,
    [Parameter(Mandatory = $True)][string]$sourceClusterName,
    [Parameter()][string]$sourceUsername,
    [Parameter()][string]$sourceDomain,
    [Parameter()][string]$sourcePassword = $null,
    [Parameter()][string]$sourceMfaCode = $null,
    [Parameter()][string]$snapshotDate = $null
)

# gather view list

if($viewList){
    $myViews = get-content $viewList
}elseif($viewNames){
    $myViews = @($viewNames)
}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thatCluster = heliosCluster $sourceClusterName
    if(! $thatCluster){
        exit 1
    }
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}else{
    $targetContext = getContext
    if(!$sourceUsername){
        $sourceUsername = $username
    }
    if(!$sourceDomain){
        $sourceDomain = $domain
    }
    # authenticate
    apiauth -vip $sourceClusterName -username $sourceUsername -domain $sourceDomain -passwd $sourcePassword -apiKeyAuthentication $useApiKey -mfaCode $sourceMfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt -quiet

    # exit on failed authentication
    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated to $sourceClusterName" -ForegroundColor Yellow
        exit 1
    }
    $sourceContext = getContext
    setContext $targetContext
}
# end authentication =========================================

function switchTo($context){
    if($USING_HELIOS){
        if($context -eq 'source'){
            $thisCluster = heliosCluster $sourceClusterName
        }else{
            $thisCluster = heliosCluster $clusterName
        }
    }else{
        if($context -eq 'source'){
            setContext $sourceContext
        }else{
            setContext $targetContext
        }
    }
}

$migratedShares = "migratedShares.txt"
$null = Remove-Item -Path $migratedShares -Force -ErrorAction SilentlyContinue

$metaDatas = @{}

foreach($viewName in $myViews){
    $viewName = [string]$viewName
    switchTo 'source'
    $sourceViews = api get views?viewName=$viewName
    $metadata = $sourceViews.views | Where-Object name -eq $viewName
    switchTo 'target'
    if(!$metadata){
        Write-Host "View $viewName not found on source cluster" -ForegroundColor Yellow
        continue
    }
    $metaDatas["$viewName"] = $metadata 
    $newViewName = "$($metadata.name)-$($suffix)"
    ### search for view to clone
    $searchResults = api get /searchvms?entityTypes=kView`&vmName=$viewName
    $viewResults = $searchResults.vms | Where-Object { $_.vmDocument.objectName -ieq $viewName }
    if($viewResults){
        $viewResult = ($viewResults | Sort-Object -Property {$_.vmDocument.versions[0].snapshotTimestampUsecs} -Descending:$True)[0]
    }else{
        Write-Host "$viewName not replicated to this cluster" -ForegroundColor Yellow
        continue
    }
    
    $doc = $viewResult.vmDocument
    $versions = $viewResult.vmDocument.versions
    $processView = $True
    $version = $versions[0]
    if($snapshotDate){
        $snapshotUsecs = dateToUsecs $snapshotDate
        $versions = $viewResult.vmDocument.versions | Where-Object {$_.instanceId.jobStartTimeUsecs -le ($snapshotUsecs + 60000000)}
        if($versions.Count -gt 0){
            $version = $versions[0]
        }else{
            $processView = $false
            Write-Host "No backups for $viewName available from $snapshotDate" -ForegroundColor Yellow
            continue
        }
    }
    $cloneTask = @{
        "name"       = "Clone-View_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
        "objects"    = @(
            @{
                "jobUid"         = $doc.objectId.jobUid;
                "jobId"          = $doc.objectId.jobId;
                "jobInstanceId"  = $version.instanceId.jobInstanceId;
                "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                "entity"         = $doc.objectId.entity; 
            }
        )
        "viewName"   = "$newViewName";
        "action"     = 5;
        "viewParams" = @{
            "sourceViewName"        = $doc.objectId.entity.displayName;
            "cloneViewName"         = "$newViewName";
            "viewBoxId"             = $doc.viewBoxId;
            "viewId"                = $doc.objectId.entity.id;
        }
    }
    Write-Host "cloning $viewName to $newViewName"
    $cloneOp = api post /clone $cloneTask
    if ($cloneOp) {
        "$newViewName" | Out-File -FilePath $migratedShares -Append
    }
}

Start-Sleep 3

foreach($viewName in $myViews){
    $viewName = [string]$viewName
    $newViewName = "$($viewName)-$($suffix)"
    $views = api get views?viewNames=$newViewName
    $newView = ($views.views | Where-Object name -eq $newViewName)
    if($newView){
        $newView = $newView[0]
        if($newView.PSObject.Properties['createTimeMsecs']){
            $metadata = $metaDatas["$viewName"]
            if(!$metadata){
                Write-Host "View $viewName not found on source cluster" -ForegroundColor Yellow
                continue
            }
            $newView.enableSmbViewDiscovery = $metadata.enableSmbViewDiscovery
            $newView.qos = @{
                "principalName" = $metadata.qos.principalName;
            }
            if($metadata.PSObject.Properties['subnetWhitelist']){
                if(! $newView.PSObject.Properties['subnetWhiteList']){
                    $newView | Add-Member -MemberType NoteProperty -Name subnetWhiteList -Value @()
                }
                $newView.subnetWhitelist = $metadata.subnetWhiteList
            }
            $null = api put views $newView
            if($metadata.PSObject.Properties['aliases']){
                write-host "`nCreating Shares..."
                foreach($alias in $metadata.aliases){
                    $newAliasName = "$($alias.aliasName)-$($suffix)"
                    write-host "`t$newAliasName"
                    $viewPath = $alias.viewPath.trimend("/")
                    $null = api post viewAliases @{'viewName' = "$($newView.name)"; 'viewPath' = $viewPath; 'aliasName' = "$newAliasName"; 'sharePermissions' = $alias.sharePermissions}
                    "$newAliasName" | Out-File -FilePath $migratedShares -Append
                }
            }
        }
    }else{
        Write-Host "New view $newViewName not found" -ForegroundColor Yellow
    }
}
