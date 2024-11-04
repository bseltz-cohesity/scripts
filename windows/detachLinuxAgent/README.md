# Detach Linux Agent from Cluster (for Windows)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a compiled binary that updates the Cohesity agent configuration on a Linux host, to disassociate it from its cluster.

## Download The Binary

<https://github.com/cohesity/community-automation-samples/raw/main/windows/detachLinuxAgent/detachLinuxAgent.exe>

Run the tool like so:

```bash
#example
detachLinuxAgent.exe -s myhost1 -u myusername
#end example
```

## Parameters

* -s, --servername: (optional) one or more hosts to connect to via SSH (repeat for multiple)
* -l, --serverlist: (optional) text file of hosts to connect to (one per line)
* -u, --username: username for SSH connection
* -pwd, --sourcepassword: (optional) will be prompted if omitted
