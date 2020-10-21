### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local' #local or AD domain
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$outFile = "principals-$($cluster.name).txt"
$null = Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue

$roles = api get roles
$users = api get users?_includeTenantInfo=true
$groups = api get groups?_includeTenantInfo=true
$parents = @{}

function showPermissions($p, $ptype){
    if($ptype -eq ' user'){
        $pname = $p.username
    }else{
        $pname = $p.name
    }
    "`n{0}: {1}/{2}" -f $ptype.ToUpper(), $p.domain, $pname
    if($p.PSObject.Properties['roles']){
        $proles = $roles | Where-Object name -in $p.roles
        "Roles: {0}" -f $proles.label -join ', '
        if($p.restricted -eq $True){
            "Access List:"
            $psources = api get principals/protectionSources?sids=$($p.sid)
            foreach($source in $psources[0].protectionSources){
                $sourceName = $source.name
                $sourceType = $source.environment.substring(1)
                $parentId = $source.parentId
                if($parentId){
                    if($parentId -in $parents.Keys){
                        $parentName = $parents[$parentId]
                    }else{
                        $parent = api get protectionSources/objects/$parentId
                        $parents[$parentId] = $parent.name
                        $parentName = $parent.name
                    }
                    "       {0}/{1} ({2})" -f $parentName, $sourceName, $sourceType
                }else{
                    "       {0} ({1})" -f $sourceName, $sourceType
                }

                
            }
            foreach($view in $psources[0].views){
                "       {0} ({1})" -f $view.name, "View"
            }
        }
    }
}


foreach($user in $users | Sort-Object -Property username){
    showPermissions $user ' User' | Tee-Object -FilePath $outFile -Append
}

foreach($group in $groups | Sort-Object -Property name){
    showPermissions $group 'Group' | Tee-Object -FilePath $outFile -Append
}
