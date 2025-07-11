### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][string]$viewName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

function principalName($sid){
    if($principals[$sid]){
        $principalName = $principals[$sid]
    }else{
        $principal = api get principals/searchPrincipals?sids=$($sid)
        $principalName = $principal.principalName
        if($principal.PSObject.Properties['domain']){
            $principalName = "$($principal.domain)\$principalName"
        }
        if(!$principalName){
            $principalName = $sid
        }
        $principals[$sid] = $principalName
    }
    return $principalName
}

$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')

$cluster = api get cluster
$outFile = Join-Path -Path $PSScriptRoot -ChildPath "smbViews-$($cluster.name)-$dateString.txt"

$users = api get users
$groups = api get groups
$principals = @{}
foreach($principal in $users){
    $principals[$principal.sid] = "$($principal.domain)\$($principal.username)"
}
foreach($principal in $groups){
    $principals[$principal.sid] = "$($principal.domain)\$($principal.name)"
}

"$dateString" | Out-File -FilePath $outFile

$views = api get -v2 file-services/views
$shares = (api get shares).sharesList | Where-Object {$_.shareName -ne $_.viewName}

if($viewName){
    $views.views = $views.views | Where-Object name -eq $viewName
}

foreach($view in ($views.views | Where-Object {'SMB' -in $_.protocolAccess.type} | Sort-Object -Property name)){
    "`n$($view.name)" | Tee-Object -FilePath $outFile -Append
    $thisView = api get views/$($view.name)
    "`n    Share Permissions:" | Tee-Object -FilePath $outFile -Append
    # share permissions
    foreach($permission in $thisView.sharePermissions){
        $principalName = principalName $permission.sid
        "        {0}: {1} {2}" -f $principalName, $permission.type.subString(1), $permission.access.subString(1) | Tee-Object -FilePath $outFile -Append
    }
    # owner
    $principalName = principalName $thisView.smbPermissionsInfo.ownerSid
    "`n    NTFS Permissions (Owner {0}):" -f $principalName | Tee-Object -FilePath $outFile -Append
    # permissions
    foreach($permission in $thisView.smbPermissionsInfo.permissions){
        $principalName = principalName $permission.sid
        "        {0}: {1} {2} on {3}" -f $principalName, $permission.type.subString(1), $permission.access.subString(1), $permission.mode.subString(1) | Tee-Object -FilePath $outFile -Append
    }
    $childShares = $shares | Where-Object {$_.viewName -eq $view.name}
    if($childShares){
        "`n    Child Shares:" | Tee-Object -FilePath $outFile -Append
    }
    foreach($childShare in $childShares){
        "`n        {0} - {1} - Share Permissions:" -f $childShare.shareName, "/$($view.name)/$($childShare.path)" | Tee-Object -FilePath $outFile -Append
        foreach($permission in $childShare.sharePermissions){
            $principalName = principalName $permission.sid
            "            {0}: {1} {2}" -f $principalName, $permission.type.subString(1), $permission.access.subString(1) | Tee-Object -FilePath $outFile -Append
        }

    }
}

"`nOutput saved to $outfile`n"