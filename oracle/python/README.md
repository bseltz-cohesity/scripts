# Cohesity Oracle Python Scripts

There are four Oracle related scripts that are often useful to Oracle DBAs. They are:

* restoreOracle.py: restore an Oracle database for operational recovery or testing
* cloneOracle.py: clone an Oracle database for test/dev
* destroyClone.py: tear down an Oracle clone
* backupNow.py: perform an on demand backup

## Download Commands

```bash
# Begin Download Commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/backupNow/backupNow.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/cloneOracle/cloneOracle.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/destroyClone/destroyClone.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/restoreOracle/restoreOracle.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x backupNow.py
chmod +x cloneOracle.py
chmod +x destroyClone.py
chmod +x restoreOracle.py
# End Download Commands
```

Please review the README for each:

* restoreOracle: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle>
* cloneOracle: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle>
* destroyClone: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/destroyClone>
* backupNow: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/backupNow>
