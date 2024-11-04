# If You Have Trouble Downloading Scripts

I have provided download commands for most of the scripts in this repository. Most times, the commands run successfully but on occasion, I have seen SSL related failures during the download commands. When this happens, you will see an error that looks like this:

```text
Invoke-WebRequest : The underlying connection was closed: An unexpected error occurred on a send.
At line:1 char:2
+ (Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").con ...
+  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-WebRequest], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand
```

If you see this, go to <https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/sslFix/sslFix.ps1> and paste the commands provided into your PowerShell session, then retry the download commands.

If you see any scripts where download commands have not been included, please open an issue.
