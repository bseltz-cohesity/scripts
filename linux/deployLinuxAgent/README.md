# Deploy Cohesity Agent for Linux (for Linux)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a compiled binary that deploys the Cohesity Linux agent on remote hosts via SSH.

## Download The Binary

<https://github.com/bseltz-cohesity/scripts/raw/master/linux/deployLinuxAgent/deployLinuxAgent>

Run the tool like so:

```bash
#example
./deployLinuxAgent -s myhost1 -u myusername -f ./el-cohesity-agent-6.6.0d_u6-1.x86_64.rpm
#end example
```

## Parameters

* -s, --servername: (optional) one or more hosts to connect to via SSH (repeat for multiple)
* -l, --serverlist: (optional) text file of hosts to connect to (one per line)
* -u, --username: username for SSH connection
* -pwd, --sourcepassword: (optional) will be prompted if omitted
* -f, --filepath: path to installer file
* -a, --agentuser: (optional) user to run agent service (default is root)
