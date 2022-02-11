### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$isilon, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$password = $null,
    [Parameter()][string]$path = $null,
    [Parameter()][switch]$phase1,
    [Parameter()][switch]$phase2,
    [Parameter()][switch]$phase3,
    [Parameter()][switch]$cleanUp
)

function dateToUsecs($datestring=(Get-Date)){
    if($datestring -isnot [datetime]){ $datestring = [datetime] $datestring }
    $usecs = [int64](($datestring.ToUniversalTime())-([datetime]"1970-01-01 00:00:00")).TotalSeconds*1000000
    return $usecs
}

function isilonAPI($method, $uri, $data=$null){
    $uri = $baseurl + $uri
    $result = $null
    if($data){
        $BODY = ConvertTo-Json $data -Depth 99
        if($PSVersionTable.PSEdition -eq 'Core'){
            $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $BODY -SkipCertificateCheck
        }else{
            $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $BODY
        }
    }else{
        if($PSVersionTable.PSEdition -eq 'Core'){
            $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -SkipCertificateCheck
        }else{
            $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers
        }
    }
    return $result
}

# demand modern powershell version (must support TLSv1.2)
if($Host.Version.Major -le 5 -and $Host.Version.Minor -lt 1){
    Write-Warning "PowerShell version must be upgraded to 5.1 or higher to connect to Cohesity!"
    Pause
    exit
}

if($PSVersionTable.PSEdition -eq 'Desktop'){
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
    $ignoreCerts = @"
public class SSLHandler
{
    public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
    {
        return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
    }
}
"@

    if(!("SSLHandler" -as [type])){
        Add-Type -TypeDefinition $ignoreCerts
    }
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
}

$baseurl = 'https://' + $isilon +":8080"

# authentication
if(!$password){
    $secureString = Read-Host -Prompt "Enter your password" -AsSecureString
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}
$EncodedAuthorization = [System.Text.Encoding]::UTF8.GetBytes($username + ':' + $password)
$EncodedPassword = [System.Convert]::ToBase64String($EncodedAuthorization)
$headers = @{"Authorization"="Basic $($EncodedPassword)"}

# check licenses
$licenses = isilonAPI get /platform/1/license/licenses
$license = $licenses.licenses | Where-Object name -eq 'SnapshotIQ'
if(!$license){
    Write-Host "This Isilon is not licensed for SnapshotIQ" -foregroundcolor Yellow
    exit
}

if($phase1 -or $cleanUp){
    # delete old snapshots
    Write-Host "Cleaing up old snapshots..."
    Remove-Item -Path ./cftStore.json -Force -ErrorAction SilentlyContinue
    $snapshots = isilonAPI get /platform/1/snapshot/snapshots
    $initialSnap = $snapshots.snapshots | Where-Object name -eq 'cohesityCftTestSnap1'
    if($initialSnap){
        $result = isilonAPI delete "/platform/1/snapshot/snapshots/$($initialSnap.id)"
    }
    $finalSnap = $snapshots.snapshots | Where-Object name -eq 'cohesityCftTestSnap2'
    if($finalSnap){
        $result = isilonAPI delete "/platform/1/snapshot/snapshots/$($finalSnap.id)"
    }
}

if($phase1){
    # crete initial snapshot
    if(!$path){
        Write-Host "Path is required" -foregroundcolor Yellow
        exit
    }

    Write-Host "Creating initial snapshot"
    $initialSnap = isilonAPI post /platform/1/snapshot/snapshots @{"name"= "cohesityCftTestSnap1"; "path"= $path}
    if($initialSnap){
        Write-Host "New Snap ID: $($initialSnap.id)"
    }
    exit

}elseif($phase2){
    # create second snap and start CFT job
    if(!$path){
        Write-Host "Path is required" -foregroundcolor Yellow
        exit
    }

    # check for initial snap
    $snapshots = isilonAPI get /platform/1/snapshot/snapshots
    $initialSnap = $snapshots.snapshots | Where-Object name -eq 'cohesityCftTestSnap1'
    if(!$initialSnap){
        Write-Host "Initial snapshot not found, please run this script with the -phase1 switch first" -foregroundcolor Yellow
        exit
    }

    # create second snap
    Write-Host "Creating second snapshot"
    $finalSnap = isilonAPI post /platform/1/snapshot/snapshots @{"name"= "cohesityCftTestSnap2"; "path"= $path}
    if($finalSnap){
        Write-Host "New Snap ID: $($finalSnap.id)"
    }

    # create CFT job
    $nowMsecs = [int64]((dateToUsecs) / 1000)
    $newCFTjob = @{
        "allow_dup" = $false;
        "policy" = "LOW";
        "priority" = 5;
        "type" = "ChangelistCreate";
        "changelistcreate_params" = @{
            "older_snapid" = $initialSnap.id;
            "newer_snapid" = $finalSnap.id
        }
    }
    $job = isilonAPI post  "/platform/1/job/jobs?_dc=$nowMsecs" $newCFTjob
    $jobId = $job.id
    $startTimeUsecs = dateToUsecs

    # write job ID and start time to json file
    @{'jobId' = $jobId; 'startTimeUsecs' = $startTimeUsecs} | ConvertTo-Json | Out-File -FilePath cftStore.json

}elseif($phase3){
    # check if job is complete and display run duration

    # read json file
    if(! (Test-Path -Path 'cftStore.json')){
        Write-Host "Please run the script with -phase1 and then with -makeCFT first"
        exit 
    }
    $cftStore = Get-Content cftStore.json | ConvertFrom-Json
    $jobId = $cftStore.jobId
    $startTimeUsecs = $cftStore.startTimeUsecs

    # report status or duration of CFT job
    $reports = isilonAPI get /platform/1/job/reports?job_type=ChangelistCreate    
    $reports = $reports.reports | Where-Object job_id -eq $jobId
    if($reports.count -lt 4){
        Write-Host $reports
        Write-Host "CFT job has not completed yet" -foregroundcolor Magenta
        exit
    }else{
        $endTimeUsecs = $reports[0].time * 1000000
        $ts = [TimeSpan]::FromSeconds([math]::Round(($endTimeUsecs - $startTimeUsecs) / 1000000))
        $duration = "{0}:{1:d2}:{2:d2}:{3:d2}" -f $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds
        Write-Host "CFT job completion time $duration" -foregroundcolor Green
    }
}
