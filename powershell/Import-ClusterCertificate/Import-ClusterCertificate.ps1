<#
.SYNOPSIS
    Pulls the CA/root certificate(s) a Cohesity cluster uses to sign its
    web-serving cert (SmartFiles/Iris) straight from the cluster's REST API
    and imports them into the local Windows Trusted Root / Intermediate CA
    stores on the ADFR Management Server -- replacing the manual
    "iris_cli -> save file -> import via certmgr" workflow.

.DESCRIPTION
    Confirmed against Cohesity's v2 cluster REST API spec (cluster_v2_api.yaml):

      GET /webserver-certificate  (v2)
        -> { certificate, certificateInfo,
             rootCa: { certificate, certificateInfo },
             intermediateCaList: [ { certificate, certificateInfo }, ... ],
             lastUpdateTimeMsecs }
        certificate/rootCa.certificate/intermediateCaList[].certificate are
        plain PEM strings (not base64-wrapped binary) -- this is the CA
        that signed the cluster's current SmartFiles/Iris serving cert,
        i.e. exactly what needs to land in ADFR MS's Trusted Root store.

      GET /trusted-cas  (v2)
        -> { certificates: [ { id, name, description, certificate,
             status: Valid|Expired|Revoked|Unknown, commonName, isCA,
             selfSigned, serialNumber, sha256Fingerprint, ... } ] }
        This is the list iris_cli's `trusted-cas register` populates --
        i.e. any CA certs someone has explicitly registered with the
        cluster by hand (the "generate the CA signed certs via iris_cli"
        step from the email). Anything with status "Valid" here is also
        pulled and trusted locally.

    Note on "Secrets Manager API": the cluster also exposes
    /secret-manager/certificates, but per the spec its `environment` enum
    is currently limited to `microsoft365` -- it's the M365/Exchange
    protection cert store, not a general-purpose cert API for
    SmartFiles/ADFR. That's consistent with it being "not enabled" for
    this use case; the CSR + trusted-cas + webserver-certificate endpoints
    above are the real path regardless of whether Secrets Manager is on.

    Cert *generation* (CSR creation + getting it signed by a CA) is a
    separate, more sensitive flow that this script deliberately does not
    automate -- POST /csr creates a CSR, but nothing in the API signs it;
    that still has to happen against whatever CA is issuing the cert
    (self-signed, internal PKI, etc.) before POST /csr/certificate attaches
    the signed cert back to the cluster. Once that's done (however it's
    done), this script's job is to pull the resulting trust material and
    push it into ADFR MS -- the two manual steps from the email.

    Uses Brian Seltzer's cohesity-api.ps1 helper library for auth/API
    calls and is meant to run ON the ADFR Management Server (local import
    into Cert:\LocalMachine).

.PARAMETER vip
    Cluster IP/FQDN.

.PARAMETER username / domain / password / useApiKey / mfaCode / emailMfaCode / noPrompt
    Same meaning as in cohesity-api.ps1's apiauth (passed straight through).

.PARAMETER caCertFile
    Import-only mode: skip the cluster API entirely and import an
    already-exported CA cert file (.pem/.cer) into Trusted Root. Use this
    if you'd rather keep the "generate" step manual for now and only
    automate the "get it into ADFR" half.

.PARAMETER includeExpired
    By default only certs with status "Valid" (from /trusted-cas) are
    imported. Pass this to also import Expired/Revoked/Unknown ones
    (not recommended -- mainly for troubleshooting).

.PARAMETER outputFolder
    Where fetched CA cert files get saved locally. Default: .\certs

.PARAMETER showRawResponse
    Dumps the raw JSON from /webserver-certificate and /trusted-cas.

.PARAMETER dryRun
    Fetches and shows what would be imported (subject, thumbprint, expiry,
    target store) without actually touching the cert store.

.EXAMPLE
    # Full pipeline: pull the cluster's root/intermediate CA + any
    # registered trusted CAs, import them all locally on the ADFR MS
    .\Import-ClusterCertificate -vip mycluster.corp.local -username admin -domain local

.EXAMPLE
    # Import-only: you already have the CA cert file, just trust it
    .\Import-ClusterCertificate -CaCertFile C:\certs\clusterCA.pem

.NOTES
    Must be run elevated (Administrator) -- writing to
    Cert:\LocalMachine\Root/CA requires it.
    Assumes cohesity-api.ps1 sits next to this script (standard layout for
    github.com/bseltz-cohesity/scripts). If missing, grab it from:
    https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1
#>

[CmdletBinding()]
param(
    [Parameter()][string]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][switch]$noPrompt,

    [Parameter()][string]$caCertFile,
    [Parameter()][switch]$includeExpired,

    [Parameter()][string]$outputFolder = '.\certs',
    [Parameter()][switch]$showRawResponse,
    [Parameter()][switch]$dryRun
)

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "This script must be run as Administrator (writing to the local machine cert store requires it). Re-launch PowerShell elevated and try again." -ForegroundColor Yellow
        exit 1
    }
}

# Imports a PEM string into a local machine cert store, skipping it if the
# thumbprint is already present. $storeName is 'Root' (Trusted Root CAs) or
# 'CA' (Intermediate CAs).
function Import-PemToStore {
    param(
        [string]$pem,
        [string]$storeName,
        [string]$savePath,
        [switch]$dryRun
    )

    Set-Content -Path $savePath -Value $pem -NoNewline
    # belt-and-suspenders: re-resolve to an absolute path even if the caller
    # passed something relative, so Import()/Import-Certificate below never
    # hit the $PWD-vs-CurrentDirectory mismatch that causes a false
    # "cannot find the path specified" error.
    $savePath = (Resolve-Path -Path $savePath).Path
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import($savePath)
    $thumbprint = $cert.Thumbprint

    Write-Host "  Subject:    $($cert.Subject)"
    Write-Host "  Thumbprint: $thumbprint"
    Write-Host "  Expires:    $($cert.NotAfter)"
    Write-Host "  Target:     Cert:\LocalMachine\$storeName"

    $existing = Get-ChildItem -Path "Cert:\LocalMachine\$storeName" | Where-Object { $_.Thumbprint -eq $thumbprint }
    if ($existing) {
        Write-Host "  Already present -- skipped." -ForegroundColor Green
        return
    }

    if ($dryRun) {
        Write-Host "  [DryRun] Would import now." -ForegroundColor Cyan
        return
    }

    Import-Certificate -FilePath $savePath -CertStoreLocation "Cert:\LocalMachine\$storeName" | Out-Null
    Write-Host "  Imported." -ForegroundColor Green
}

Assert-Admin

if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
}
# resolve to an absolute path -- X509Certificate2.Import()/Import-Certificate
# resolve relative paths against the process's actual working directory, which
# can silently differ from PowerShell's $PWD (especially when elevated), and
# that mismatch throws "the system cannot find the path specified" even though
# the file was just written successfully via Set-Content a moment earlier.
$outputFolder = (Resolve-Path -Path $outputFolder).Path

# ---------------------------------------------------------------------
# Import-only path: skip the cluster entirely
# ---------------------------------------------------------------------
if ($caCertFile) {
    if (-not (Test-Path $caCertFile)) {
        Write-Host "CA cert file not found: $caCertFile" -ForegroundColor Yellow
        exit 1
    }
    $caCertFile = (Resolve-Path -Path $caCertFile).Path
    Write-Host "Importing $caCertFile ..."
    Import-PemToStore -pem (Get-Content $caCertFile -Raw) -storeName 'Root' -savePath $caCertFile -dryRun:$dryRun
    return
}

# ---------------------------------------------------------------------
# Full pipeline: pull trust material from the cluster's REST API
# ---------------------------------------------------------------------
if (-not $vip) {
    Write-Host "-vip is required unless you pass -CaCertFile for import-only mode." -ForegroundColor Yellow
    exit 1
}

. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

apiauth -vip $vip -username $username -domain $domain -passwd $password `
    -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode `
    -noPromptForPassword $noPrompt

if (-not $cohesity_api.authorized) {
    Write-Host "Not authenticated to $vip" -ForegroundColor Yellow
    exit 1
}

$imported = @()

# 1) the CA chain behind the cluster's active web-serving (SmartFiles/Iris) cert
Write-Host "`nFetching webserver-certificate from $vip ..."
$webCert = api get "webserver-certificate" -v2
if($cohesity_api.last_api_error -ne 'OK'){
    Write-Host "  last_api_error: $($cohesity_api.last_api_error)" -ForegroundColor DarkGray
}
if ($showRawResponse) {
    Write-Host "---- /webserver-certificate raw response ----" -ForegroundColor DarkGray
    $webCert | ConvertTo-Json -Depth 10
}

if (-not $webCert) {
    Write-Host "No response at all from /webserver-certificate -- the API call itself likely failed (see last_api_error above). This can mean the route doesn't exist on this cluster's iris version, or the account lacks privilege for it." -ForegroundColor Yellow
}
else {
    # always show what came back, even without -ShowRawResponse, so a mismatch is obvious
    if ($webCert.certificateInfo) {
        $ci = $webCert.certificateInfo
        Write-Host "  Active cert: commonName='$($ci.commonName)' isCA=$($ci.isCA) selfSigned=$($ci.selfSigned) issuedBy='$($ci.issuedBy)' issuedTo='$($ci.issuedTo)'"
    }

    if ($webCert.rootCa -and $webCert.rootCa.certificate) {
        Write-Host "Root CA:"
        $path = Join-Path $outputFolder "$vip-root-ca.pem"
        Import-PemToStore -pem $webCert.rootCa.certificate -storeName 'Root' -savePath $path -dryRun:$dryRun
        $imported += $path
    }
    elseif ($webCert.certificate) {
        # No rootCa/chain came back -- either the cert really is self-signed, or
        # it's a CA-signed leaf whose issuing chain just wasn't uploaded back to
        # the cluster (common when a cert is signed externally via iris_cli and
        # only the leaf gets applied). Either way, Windows will happily trust a
        # leaf cert placed directly in Trusted Root -- Schannel/X509Chain just
        # need the exact cert bytes to match, they don't require it to actually
        # be a CA. This is a well-known, valid workaround for "pin this one cert"
        # when you don't have/want the real chain.
        #
        # Caveat: this pins the *current* cert, not a CA. If the cluster's cert
        # is renewed/rotated (new key/serial), ADFR will stop trusting it again
        # until this script (or a manual import) is re-run with the new cert.
        # If you want trust to survive rotation, the durable fix is getting the
        # actual issuing CA cert uploaded to the cluster so rootCa gets populated
        # instead.
        if ($webCert.certificateInfo -and -not $webCert.certificateInfo.selfSigned) {
            Write-Host "No rootCa/chain returned, even though the cert doesn't look self-signed -- likely the issuing CA's chain was never uploaded back to the cluster. Trusting the leaf cert directly instead:" -ForegroundColor DarkYellow
        }
        else {
            Write-Host "Active cert is self-signed -- no separate rootCa object, trusting the cert itself:"
        }
        $path = Join-Path $outputFolder "$vip-leaf-cert.pem"
        Import-PemToStore -pem $webCert.certificate -storeName 'Root' -savePath $path -dryRun:$dryRun
        $imported += $path
    }
    else {
        Write-Host "No certificate field at all in the response -- rerun with -ShowRawResponse to see what actually came back." -ForegroundColor Yellow
    }
}

if ($webCert -and $webCert.intermediateCaList) {
    $i = 0
    foreach ($ica in $webCert.intermediateCaList) {
        if (-not $ica.certificate) { continue }
        $i++
        Write-Host "Intermediate CA #$i`:"
        $path = Join-Path $outputFolder "$vip-intermediate-ca-$i.pem"
        Import-PemToStore -pem $ica.certificate -storeName 'CA' -savePath $path -dryRun:$dryRun
        $imported += $path
    }
}

# 2) anything explicitly registered on the cluster (iris_cli trusted-cas register).
# NOTE: this list is what the *cluster* trusts for its own outbound connections
# (e.g. to an LDAP/KMS server) -- it is usually NOT where the cluster's own
# serving cert shows up, so an empty list here is normal/expected and doesn't
# by itself indicate a problem. It's included as a bonus source, not the
# primary one -- /webserver-certificate above is the one that matters.
Write-Host "`nFetching trusted-cas list from $vip ..."
$trustedCas = api get "trusted-cas" -v2
if($cohesity_api.last_api_error -ne 'OK'){
    Write-Host "  last_api_error: $($cohesity_api.last_api_error)" -ForegroundColor DarkGray
}
if ($showRawResponse) {
    Write-Host "---- /trusted-cas raw response ----" -ForegroundColor DarkGray
    $trustedCas | ConvertTo-Json -Depth 10
}

if ($trustedCas -and $trustedCas.certificates) {
    foreach ($tca in $trustedCas.certificates) {
        if (-not $tca.certificate) { continue }
        if ($tca.status -ne 'Valid' -and -not $includeExpired) {
            Write-Host "Skipping trusted-ca '$($tca.name)' (status: $($tca.status)) -- pass -IncludeExpired to import anyway." -ForegroundColor DarkYellow
            continue
        }
        Write-Host "Trusted CA '$($tca.name)' (status: $($tca.status)):"
        $safeName = ($tca.name -replace '[^a-zA-Z0-9_-]', '_')
        $path = Join-Path $outputFolder "$vip-trusted-ca-$safeName.pem"
        Import-PemToStore -pem $tca.certificate -storeName 'Root' -savePath $path -dryRun:$dryRun
        $imported += $path
    }
}

if ($imported.Count -eq 0) {
    Write-Host "`nNothing to import -- no CA certificates were returned by either endpoint." -ForegroundColor Yellow
    exit 1
}

Write-Host "`nDone. $($imported.Count) cert file(s) saved under $outputFolder." -ForegroundColor Green
