# Customer-Managed — Developer Guide / Examples

[← Back to Customer-Managed](index.md)

Total scripts: **13**

## Cluster & System Administration (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [auth-example-multi.ps1](https://github.com/cohesity/community-automation-samples/tree/main/devGuide/powershell/examples/auth-example-multi) | PowerShell | 2026-07-06 | This PowerShell script provides all the command line options and functions to authenticate to multiple Cohesity clusters, directly or through Helios, using the various authentication methods available (v1 accessTokens, v2 sessions, UI login, and API keys). |
| [auth-example.ps1](https://github.com/cohesity/community-automation-samples/tree/main/devGuide/powershell/examples/auth-example) | PowerShell | 2026-07-06 | This PowerShell script provides all the command line options and functions to authenticate to a Cohesity cluster, directly or through Helios, using the various authentication methods available (v1 accessTokens, v2 sessions, UI login, and API keys). |

## Cluster Create (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [vlanConfigExample.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addVlan) | PowerShell | 2024-11-04 | This script adds a VLAN to the networking configuration of a Cohesity cluster. (example configuration file) |

## Protection & Recovery (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [protectionRunsV1Example.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectionRunsV1Example) | PowerShell | 2024-11-04 | This PowerShell script demonstrates how to gather protection runs using the v1 API in a scalable way. |
| [protectionRunsV1Example.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectionRunsV1Example) | Python | 2024-11-04 | This python script demonstrates how to gather protection runs using the v1 API in a scalable way. |
| [runs-example.ps1](https://github.com/cohesity/community-automation-samples/tree/main/devGuide/powershell/examples/runs-example) | PowerShell | 2026-07-06 | This PowerShell script provides all the command line options and functions to authenticate to a Cohesity cluster, directly or through Helios, using the various authentication methods available (v1 accessTokens, v2 sessions, UI login, and API keys), and gather the list of protection runs for each protection group. |
| [runsExample.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/runsExample) | Bash/Shell | 2024-11-04 | This bash script is just an example of how to iterate over protection groups and runs using curl and jq. |

## User, Access & Security (6)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [accessToken.ps1](https://github.com/cohesity/community-automation-samples/tree/main/devGuide/powershell/rudiments) | PowerShell | 2026-07-06 | Provided here are some rudimentary examples to provide understanding of basic principles of Cohesity API authentication and access. These examples use PowerShell's Invoke-RestMethod commandlet (they do not user cohesity-api.ps1. cohesity-api.ps1 uses these same techniques under the covers). |
| [apiKey.ps1](https://github.com/cohesity/community-automation-samples/tree/main/devGuide/powershell/rudiments) | PowerShell | 2026-07-06 | Provided here are some rudimentary examples to provide understanding of basic principles of Cohesity API authentication and access. These examples use PowerShell's Invoke-RestMethod commandlet (they do not user cohesity-api.ps1. cohesity-api.ps1 uses these same techniques under the covers). |
| [example-deployCVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployCVE) | PowerShell | 2024-11-04 | This PowerShell script deploys a multi-node Cohesity Virtual Edition (VE) cluster on VMware vSphere. After deploying the OVA, the script performs the cluster setup, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login. |
| [helios.ps1](https://github.com/cohesity/community-automation-samples/tree/main/devGuide/powershell/rudiments) | PowerShell | 2026-07-06 | Provided here are some rudimentary examples to provide understanding of basic principles of Cohesity API authentication and access. These examples use PowerShell's Invoke-RestMethod commandlet (they do not user cohesity-api.ps1. cohesity-api.ps1 uses these same techniques under the covers). |
| [userSession.ps1](https://github.com/cohesity/community-automation-samples/tree/main/devGuide/powershell/rudiments) | PowerShell | 2026-07-06 | Provided here are some rudimentary examples to provide understanding of basic principles of Cohesity API authentication and access. These examples use PowerShell's Invoke-RestMethod commandlet (they do not user cohesity-api.ps1. cohesity-api.ps1 uses these same techniques under the covers). |
| [webSession.ps1](https://github.com/cohesity/community-automation-samples/tree/main/devGuide/powershell/rudiments) | PowerShell | 2026-07-06 | Provided here are some rudimentary examples to provide understanding of basic principles of Cohesity API authentication and access. These examples use PowerShell's Invoke-RestMethod commandlet (they do not user cohesity-api.ps1. cohesity-api.ps1 uses these same techniques under the covers). |
