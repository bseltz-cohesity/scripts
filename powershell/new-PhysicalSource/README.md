# Register New Physical Protection Source using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script registers a new physical host as a Cohesity protection source.

## Components

* new-PhysicalSource.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then run the script like so.

```powershell
./new-PhysicalSource.ps1 -vip bseltzve01 -username admin -server w2012c.seltzer.net                                                    Connected!
New Physical Server Registered. ID: 597
```

```powershell
./new-PhysicalSource.ps1 -vip bseltzve01 -username admin -server 192.168.1.10     
Connected!                                                            New Physical Server Registered. ID: 593
```

Note that the Cohesity agent must be installed on the host and that firewall port 50051/tcp on the host must be accessible by the Cohesity cluster. 