# Set Agent Gflags on Linux using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script sets Cohesity agent gflags on linux hosts, via SSH.

`Note`: this script requires the paramiko python module. See [Installing - Paramiko documentation](https://www.paramiko.org/installing.html)

## Download the script

Run this commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/agentGflags/agentGflags.py
chmod +x agentGflags.py
```

## Components

* [agentGflags.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/agentGflags/agentGflags.py): the main python script

Run the main script like so:

To see the current agent gflag settings on a linux host (if any):

```bash
#example
./agentGflags.py -s myhost1 -u myusername
#end example
```

To set an agent gflag:

```bash
#example
./agentGflags.py -s myhost1 -u myusername -n max_rpc_context_count -v 32
#end example
```

To set multiple agent gflags:

```bash
#example
./agentGflags.py -s myhost1 -u myusername -n max_rpc_context_count -v 32 -n grpc_server_cq_control_threads -v 2
#end example
```

## Parameters

* -s, --servername: (optional) one or more hosts to connect to via SSH (repeat for multiple)
* -l, --serverlist: (optional) text file of hosts to connect to (one per line)
* -u, --username: username for SSH connection
* -pwd, --sourcepassword: (optional) will be prompted if omitted
* -n, --flagname: (optional) name of flag to apply (repeat for multiple)
* -v, --flagvalue: (optional) value of flag to apply (repeat for multiple)
* -c, --clear: (optional) clear the specified flag name(s)
