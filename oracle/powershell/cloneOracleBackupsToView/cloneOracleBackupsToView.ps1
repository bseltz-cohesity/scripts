# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$access,
    [Parameter()][string]$objectName,
    [Parameter(Mandatory=$True)][string]$jobName,
    [Parameter()][string]$viewName,
    [Parameter()][switch]$deleteView,
    [Parameter()][switch]$force,
    [Parameter()][Int64]$numRuns = 100,
    [Parameter()][array]$ips,                         # optional cidrs to add (comma separated)
    [Parameter()][string]$ipList = '',                # optional textfile of cidrs to add
    [Parameter()][switch]$readOnly                    # grant only read access
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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
    return ($items | Sort-Object -Unique)
}

function netbitsToDDN($netBits){
    $maskBits = '1' * $netBits + '0' * (32 - $netBits)
    $octet1 = [convert]::ToInt32($maskBits.Substring(0,8),2)
    $octet2 = [convert]::ToInt32($maskBits.Substring(8,8),2)
    $octet3 = [convert]::ToInt32($maskBits.Substring(16,8),2)
    $octet4 = [convert]::ToInt32($maskBits.Substring(24,8),2)
    return "$octet1.$octet2.$octet3.$octet4"
}

function newWhiteListEntry($cidr, $perm){
    $ip, $netbits = $cidr -split '/'
    if(! $netbits){
        $netbits = '32'
    }
    $maskDDN = netbitsToDDN $netbits
    $whitelistEntry = @{
        "nfsAccess" = $perm;
        "smbAccess" = $perm;
        "s3Access" = $perm;
        "ip"            = $ip;
        "netmaskIp4"    = $maskDDN
    }
    return $whitelistEntry
}

$ipaddrs = @(gatherList -Param $ips -FilePath $ipList -Name 'whitelist ips' -Required $false)

$perm = 'kReadWrite'
if($readOnly){
    $perm = 'kReadOnly'
}

if(!$deleteView){
    if(!$jobName){
        Write-Host "JobName parameter required" -ForegroundColor Yellow
        exit 1
    }
}
if(!$viewName){
    $viewName = "$jobName".Replace(' ','-')
}

$views = api get "views?includeInternalViews=true"
$view = $views.views | Where-Object {$_.name -eq $viewName}

# delete view
if($deleteView){
    "Deleting old view..."
    if(!$force){
        write-host "*** Warning: you are about to delete view $viewName! ***" -ForegroundColor Red
        $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
        if($confirm.ToLower() -eq 'yes' -or $confirm.ToLower() -eq 'y'){
            $null = api delete "views/$viewName"
        }
    }else{
        $null = api delete "views/$viewName"
    }
    exit 0
}

# find job
$job = api get protectionJobs | Where-Object name -eq $jobName
if(!$job){
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
    exit 1
}
$job = ($job | Sort-Object id)[-1]

$storageDomainId = $job.viewBoxId


$runs = (api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns") | Where-Object{ $_.backupRun.snapshotsDeleted -eq $false }

if(!$view){
    $newView = @{
        "enableSmbAccessBasedEnumeration" = $false;
        "enableSmbViewDiscovery"          = $true;
        "fileDataLock"                    = @{
            "lockingProtocol" = "kSetReadOnly"
        };
        "fileExtensionFilter"             = @{
            "isEnabled"          = $false;
            "mode"               = "kBlacklist";
            "fileExtensionsList" = @()
        };
        "securityMode"                    = "kNativeMode";
        "sharePermissions"                = @();
        "smbPermissionsInfo"              = @{
            "ownerSid"    = "S-1-5-32-544";
            "permissions" = @()
        };
        "protocolAccess"                  = "kSMBOnly";
        "subnetWhitelist"                 = @();
        "caseInsensitiveNamesEnabled"     = $true;
        "storagePolicyOverride"           = @{
            "disableInlineDedupAndCompression" = $false
        };
        "qos"                             = @{
            "principalName" = "TestAndDev High"
        };
        "viewBoxId"                       = $storageDomainId;
        "name"                            = $viewName
    }
 
    function addPermission($user, $perms){
        $domain, $domainuser = $user.split('\')
        $principal = api get "activeDirectory/principals?domain=$domain&includeComputers=true&search=$domainuser" | Where-Object fullName -eq $domainuser
        if($principal){
            $permission = @{
                "sid" = $principal.sid;
                "type" = "kAllow";
                "mode" = "kFolderSubFoldersAndFiles";
                "access" = $perms
            }
            $newView.sharePermissions += $permission
            $newView.smbPermissionsInfo.permissions += $permission
        }else{
            Write-Warning "User $user not found"
            exit 1
        }
    }

    if($access){
        foreach($user in $access){
            addPermission $user 'kFullControl'
        }
    }else{
        $permission += @{
            "sid" = "S-1-1-0";
            "access" = "kFullControl";
            "mode" = "kFolderSubFoldersAndFiles";
            "type" = "kAllow"
        }
        $newView.sharePermissions += $permission
        $newView.smbPermissionsInfo.permissions += $permission
    }

    Write-Host "Creating new view $viewName"
    $view = api post views $newView
}

Write-Host "Cloning backup files..."
Start-Sleep 3
$view = (api get views).views | Where-Object {$_.name -eq $viewName}

# add whitelist entries
if($ipaddrs.Count -gt 0){
    if(! $view.PSObject.Properties['subnetWhitelist']){
        setApiProperty -object $view -name 'subnetWhitelist' -value @()
    }
    
    foreach($cidr in $ipaddrs){
        $ip, $netbits = $cidr -split '/'
        $view.subnetWhitelist = @($view.subnetWhiteList | Where-Object ip -ne $ip)
        $view.subnetWhitelist = @($view.subnetWhiteList +(newWhiteListEntry $cidr $perm))
    }
    $null = api put views $view
}

$paths = @()
$thisObjectFound = $False
foreach($run in $runs){
    $runType = $run.backupRun.runType
    foreach($sourceInfo in $run.backupRun.sourceBackupStatus){
        $thisObjectName = $sourceInfo.source.name
        if(! $objectname -or $thisObjectName -eq $objectName){
            $thisObjectFound = $True
            $sourceView = $views.views | Where-Object {$_.name -match "_$($run.backupRun.jobRunId)_" -and $_.name -match "_$($job.id)_"}
            if($sourceView){
                $starttimeString = (usecsToDate $run.backupRun.stats.startTimeUsecs).ToString("yyyy-MM-dd_HH-mm-ss")
                $destinationPath = "$($thisObjectName)-$($starttimeString)-$($runType)"
                $CloneDirectoryParams = @{
                    'destinationDirectoryName' = $destinationPath;
                    'destinationParentDirectoryPath' = "/$($viewName)";
                    'sourceDirectoryPath' = "/$($sourceView[0].name)"
                }
                $folderPath = "\\$($vip)\$viewName\$destinationPath"
                Write-Host "Cloning $thisObjectName backup files to $folderPath"
                $result = api post views/cloneDirectory $CloneDirectoryParams
            }
        }
    }
}
if($thisObjectFound -eq $False){
    Write-Host "No runs found containing $objectName" -ForegroundColor Yellow
}

$backupFolderPath = "\\$vip\$viewName"

write-host "`nFiles cloned to $backupFolderPath`n" 
