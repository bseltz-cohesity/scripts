# Cohesity REST API Scripts Using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

Sometimes you need a screwdriver but all you have is a butter knife!

These example scripts use pure bash, curl and sed to make REST API calls to Cohesity. When more advanced scripting languages such as PowerShell and Python are unavailable, you can make due with these core utilities.

## Dependencies

* curl: note that the version of curl must support TLS v1.2 to communicate with Cohesity
* sed: uses sed regular expressions to parse JSON responses
