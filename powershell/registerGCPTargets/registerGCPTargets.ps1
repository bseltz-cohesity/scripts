[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][string]$keyfile = 'gcpkey.txt', # text file containing private key
    [Parameter(Mandatory = $True)][string]$clientemail, # GCP idenntity
    [Parameter(Mandatory = $True)][string]$projectid, # GCP project ID
    [Parameter()][string]$inputfile = 'gcptargets.csv' # CSV input file with targetname, bucketname, tiertype
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -tenant $tenant

$gcptargets = Import-Csv -Path $inputfile
$privatekey = Get-Content -Path $keyfile -Raw

foreach($target in $gcptargets){
    $myObject = @{
        "compressionPolicy" = "kCompressionLow";
        "config" = @{
            "google" = @{
                "tierType" = $target.tiertype;
                "projectId" = $projectid;
                "clientEmailAddress" = $clientemail;
                "clientPrivateKey" = "$privatekey"
            };
            "bucketName" = $target.bucketname
        };
        "dedupEnabled" = $true;
        "encryptionPolicy" = "kEncryptionStrong";
        "incrementalArchivesEnabled" = $true;
        "name" = $target.targetname;
        "usageType" = "kArchival";
        "customerManagingEncryptionKeys" = $false;
        "externalTargetType" = "kGoogle"
    }
    "Registering target $($target.targetname) -> $($target.bucketname)"
    $null = api post vaults $myObject
}


