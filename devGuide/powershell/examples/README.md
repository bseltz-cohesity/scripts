# Cohesity REST API Examples

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These examples use the cohesity-api.ps1 function library and its apiauth function to authenticate to Cohesity clusters directly or through Helios.

* [auth-example.ps1](auth-example/README.md): authenticate to a single Cohesity cluster (directly or through Helios)
* [auth-example-multi.ps1](auth-example-multi/README.md): authenticate to a multiple Cohesity clusters (directly or through Helios)
* [auth-example-CCS.ps1](auth-example-CCS/README.md): authenticate to Cohesity Cloud Protection service (through Helios)
* [runs-example.ps1](runs-example/README.md): example of how to get protection runs and generate a simple report
