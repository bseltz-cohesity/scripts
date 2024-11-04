# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$configFolder  # folder to store export files
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get sources file
$sourcesPath = Join-Path -Path $configFolder -ChildPath 'sources.json'
if(! (Test-Path -PathType Leaf -Path $sourcesPath)){
    Write-Host "sources file not found" -ForegroundColor Yellow
    exit
}

# get id map
$idmap = @{}
$idMapPath = Join-Path -Path $configFolder -ChildPath 'idmap.json'
if(Test-Path -PathType Leaf -Path $idMapPath){
    foreach($mapentry in (Get-Content $idMapPath)){
        $oldId, $newId = $mapentry.Split('=')
        $idmap[$oldId] = $newId
    }
}

$pwdCache = @{}

# get new Nas sources
write-host "Importing NAS Registrations..."
$sources = api get protectionSources?environments=kGenericNas

# import GenericNas sources
$oldNasSources = (get-content $sourcesPath | ConvertFrom-Json) | Where-Object {$_.protectionSource.environment -eq 'kGenericNas' }
foreach($node in $oldNasSources.nodes){

    $oldId = $node.protectionSource.id
    $oldProtocol = $node.protectionSource.nasProtectionSource.protocol
    $oldMountPath = $node.protectionSource.nasProtectionSource.mountPath
    if($oldMountPath -in $sources.nodes.protectionSource.name){
        write-host "$oldMountPath already registered" -ForegroundColor Blue
    }else{
        write-host "Registering $oldMountPath" -ForegroundColor Green
        # generic NAS parameters
        $newSourceParams = @{
            'entity' = @{
                'type' = 11;
                'genericNasEntity' = @{
                    'protocol' = 1;
                    'type' = 1;
                    'path' = $oldMountPath
                }
            };
            'entityInfo' = @{
                'endpoint' = $oldMountPath;
                'type' = 11;
            }
        }
        
        if($oldProtocol -eq 'kCifs1'){
            # get SMB credentials
            $username = $node.registrationInfo.nasMountCredentials.username
            $domain = $node.registrationInfo.nasMountCredentials.domain
            
            # get SMB password
            if(! $pwdCache["$domain\$username"]){
                $secureString = Read-Host -Prompt "    Enter password for $domain\$username" -AsSecureString
                $pwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
                $pwdCache["$domain\$username"] = $pwd
            }else{
                $pwd = $pwdCache["$domain\$username"]
            }
    
            # SMB source parameters
            $newSourceParams.entity.genericNasEntity.protocol = 2 #SMB
            $credentials = @{
                'username'            = '';
                'password'            = '';
                'nasMountCredentials' = @{
                    'protocol' = 2;
                    'username' = $username;
                    'password' = $pwd;
                }
            }
            if ($domain) {
                $credentials.nasMountCredentials['domainName'] = $domain
            }
            $newSourceParams.entityInfo['credentials'] = $credentials
        }
        # register new source
        $newSource = api post /backupsources $newSourceParams
        if($newSource){
            $newId = $newSource.entity.id
            $idmap["$oldId"] = $newId
        }
    }
}
# store id map
$idmap.Keys | ForEach-Object { "$($_)=$($idmap[$_])" } | Out-File -FilePath $idMapPath
