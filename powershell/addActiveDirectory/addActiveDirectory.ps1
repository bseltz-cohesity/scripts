### usage: ./addActiveDirectory.ps1 -cluster mycluster `
#                                   -username myuser `
#                                   -domain local `
#                                   -adDomain mydomain.net `
#                                   -adUsername myuser@mydomain.net `
#                                   -adPassword bosco `
#                                   -adComputername mycluster `
#                                   -adContainer US/IT/Servers

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$cluster,   # cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username,  # cohesity username
    [Parameter()][string]$domain = 'local',           # user domain
    [Parameter()][string]$adDomain = $null,           # AD domain to join
    [Parameter()][string]$adUsername = $null,         # AD User to join domain
    [Parameter()][string]$adPassword = $null,         # AD password to join domain
    [Parameter()][string]$adComputername = $null,     # Computer account name for cluster
    [Parameter()][string]$adContainer = 'Computers',  # AD Container Path for computer account
    [Parameter()][string]$adNetbiosname = $null,      # AD Container Path for computer account
    [Parameter()][switch]$useExistingComputerAccount, # Overwrite existing computer account
    [Parameter()][string]$configFile = $null          # Optional config file to provide parameters
)

# read config file if specified
if($configFile -and (Test-Path $configFile -PathType Leaf)){
    . $configFile
}

# confirm all required parameters
if($null -eq $adDomain -or $null -eq $adUsername -or $null -eq $adPassword -or $null -eq $adComputername){
    write-host "The following parameters are required:
    -adDomain
    -adUsername
    -adPassword
    -adComputername" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $cluster -username $username -domain $domain

# define adParameters object
$adParameters = @{
    "domainName"                 = $adDomain;
    "userName"                   = $adUsername;
    "password"                   = $adPassword;
    "preferredDomainControllers" = @(
        @{
            "domainName" = $adDomain
        }
    );
    "machineAccounts"            = @(
        $adComputername
    );
    "overwriteExistingAccounts"  = $false;
    "userIdMapping"              = @{};
    "ouName"                     = $adContainer
}

# add optional NETBIOS name
if($adNetbiosname){
    $adParameters['workgroup'] = $adNetbiosname
}

# overwrite existing account
if($useExistingComputerAccount){
    $adParameters.overwriteExistingAccounts = $True
}

# join AD
"Joining $adDomain..."
$null = api post activeDirectory $adParameters
