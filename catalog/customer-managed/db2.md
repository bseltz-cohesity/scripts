# Customer-Managed — DB2

[← Back to Customer-Managed](index.md)

Total scripts: **2**

## Protection & Recovery (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [registerDB2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerDB2) | Python | 2025-02-07 | This python script registers a Universal Data Adapter DB2 protection source. |
| [restoreDB2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreDB2) | Python | 2026-08-12 | This script restores a DB2 backup. DB2 protection/recovery on this cluster is implemented through the Universal Data Adapter (UDA) framework using DB2-specific scripts, so this script builds a `kUDA` recovery request under the hood, passing DB2-specific behavior (redirected restore paths, rollforward, timeouts, etc.) to the underlying DB2 scripts as named `recoveryJobArguments`. |
