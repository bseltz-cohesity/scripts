# Running These PowerShell Scripts

## Where to Run These Scripts

No, these scripts can not be run on the Cohesity cluster. PowerShell is not installed there, and we don't go around installing things on the cluster. You can run the script from almost anywhere else where PowerShell 5.1 or later is installed, including your <img src="../images/apple-1-logo-png-transparent.png" height="16"/> Macbook, a common <img src="../images/linux_PNG1.png" height="16"/> Linux distro, a <img src="../images/Windows_logo.png" height="13"/> Windows server, you name it.

## Check Your PowerShell Version

First, let's make sure your PowerShell version is adequate. Open a PowerShell window and type:

`$host`

<img src="../images/powershellVersion.png" height="200"/>

The minimum required version is `5.1`. Older versions of Windows (like Server 2012 R2) came with PowerShell 4.0, which won't work. Older PowerShell versions can't connect to Cohesity because they didn't have support for modern HTTPS encryption standard TLSv1.2 which is required by Cohesity (and pretty much everyone else these days).

You can search Microsoft to find a patch bundle appropriate to your Windows version, to upgrade to PowerShell 5.1 (which often requires a reboot), or you can install PowerShell Core (no reboot required) for Windows, MacOS, and various Linux distributions here: <https://github.com/PowerShell/PowerShell#get-powershell>

Please install the LTS or stable version (the preview version is often problematic).

## Dependencies

There are no additional requirements to run the PowerShell scripts in this repository (you do `not` need to install the Cohesity PowerShell Module). These scripts use a function library called `cohesity-api.ps1` which is downloaded with the script if you follow the download instructions included in the README for each script.

## Opening a PowerShell Window

Just a quick note: no, you don't need to run PowerShell as administrator. If you do launch PowerShell as administrator, the default current directory will be `C:\Windows\System32` which is `not` a good place to start downloading scripts. Please change directory and make a folder for your scripts (perhaps `c:\scripts`), like:

```powershell
c:
cd \
md scripts
cd scripts
```

## Downloading a Script

Each script has a README which includes instructions to download the script, which are PowerShell commands that you can paste into a PowerShell window to pull down the files. For example:

```powershell
# Download Commands
$scriptName = 'backupNow'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

**Note**: if you find an old script that doesn't have download commands in the README, please open an issue or report it to BSeltz...

Paste the download commands into the PowerShell window (after first changing to a directory where you want the scripts to be placed). Note that PowerShell on Windows doesn't support ctrl-c/ctrl-v, you must right-click to paste, and may have to hit return to execute the final command.

If you don't follow the download instructions (if for example you clone the github repo to your machine), the files may end up having the incorrect line endings for your operating system, which will cause mysterious errors when you try to run the script.

When you paste the download commands you may receive errors that look like this:

<img src="../images/sslError.png"/>

The error indicates that PowerShell doesn't trust the SSL certificate on GitHub's web site (goodness knows why). If you see this error, paste the following commands into PowerShell.

```powershell
# commands to fix SSL
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
# end ssl commands
```

After pasting these commands, try pasting the download commands again.

## If the Download Commands Just Don't Work

If the scripts still fail to download, keep in mind that the machine may simply not have access to GitHub (due to lack of firewall access). Alternatively you can copy and paste the script code manually. To do this, click on the script file and click the `Raw` button to display ths script code in clear text. You can then select all, copy, and paste the code into a new file on the machine. You will also need a copy the the `cohesity-api.ps1` file located here: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api>

## Connecting to Cohesity Clusters over Support Channel (RT)

Most of the scripts have a `-vip` parameter which is the Cohesity cluster to connect to. When connecting to a cluster directly over the network or VPN, you can use an IP Address or DNS name (assuming you can resolve it). If you are connecting to a Cluster over RT, then the `-vip` should be the same address that the browser uses (e.g. `localhost:59083`).

## Usernames, Domains, and Passwords

Scripts also have `-username` and `-domain` parameters, and the format is the same as it is in the UI logon screen. For example, to log on as local admin, it's:

`-username admin -domain local`

Actually, `-domain` defaults to local, so you can omit the `-domain` parameter entirely if you're using a local account. For Active Directory accounts, the `-domain` should match what you see in the domain list in the UI logon screen (which is the FQDN of the Active Directory domain), like:

`-username myuser -domain mydomain.net`

Note that `-username myuser -domain mydomain` will `not` work. The domain name is `mydomain.net` not `mydomain`.

Most scripts do `not` have a `-password` parameter. The goal is to avoid typing the password in clear text on the command line, or worse, saving the password in a clear text file. Instead, when you first run a script using a specific VIP/user/domain, you will be prompted for the password, and the password will be stored, encrypted, for later use. The next time you use the same VPI/user/domain for `any` script, the stored password will be used automatically.

## Incorrect Passwords

If you fat fingered the password, or if the password has been changed in Active Directory (or in the UI), you need to update the stored password. To do this, we "dot source" the `cohesity-api.ps1` file into the current PowerShell session, so we can use the authentication function to update the password, like so:

```powershell
. .\cohesity-api.ps1
apiauth -vip mycluster -username myuser -domain mydomain.net -updatePassword
```

You will be prompted for the new password and the stored password will be updated.

Alternatively, you can delete the stored password manually. In Windows, passwords are stored in the current user's registry, under `HKEY_CURRENT_USER\Software\Cohesity-API`. In MacOS and Linux, passwords are stored in the current user's home directory under `~/.cohesity-api/`.

## Sharing Error Messages

There are two fundamental truths about error sharing:

1) If you send me a screenshot of an PowerShell error message, you are a horrible horrible person.

2) If you didn't read everything above before sharing your error, again, horrible.

PowerShell is text based, so you can copy and paste the entire command line and error output, which makes it much easier to see what you tried (so I can try it myself). Again, Windows PowerShell is annoying in that you can't just drag your mouse over the text and hit ctrl-c, instead you may have to click the little PS icon at the top left of the window, and select `Edit` -> `Mark`, then select the text and hit enter to copy the text.
