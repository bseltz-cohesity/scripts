# Set Agent Gflags on Linux (for Linux)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a compiled binary that sets Cohesity agent gflags on linux hosts, via SSH.

## Download The Binary

<https://github.com/cohesity/community-automation-samples/raw/main/linux/agentGflags/agentGflags>

Run the tool like so:

To see the current agent gflag settings on a linux host (if any):

```bash
#example
./agentGflags -s myhost1 -u myusername
#end example
```

To set an agent gflag:

```bash
#example
./agentGflags -s myhost1 -u myusername -n max_rpc_context_count -v 32
#end example
```

To set multiple agent gflags:

```bash
#example
./agentGflags -s myhost1 -u myusername -n max_rpc_context_count -v 32 -n grpc_server_cq_control_threads -v 2
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
