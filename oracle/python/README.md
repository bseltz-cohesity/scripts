# Cohesity Oracle Python Scripts

There are four Oracle related scripts that are often useful to Oracle DBAs. They are:

* restoreOracle.py: restore an Oracle database for operational recovery or testing
* cloneOracle.py: clone an Oracle database for test/dev
* destroyClone.py: tear down an Oracle clone
* backupNow.py: perform an on demand backup

## Download Commands

```bash
# Begin Download Commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/backupNow/backupNow.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/cloneOracle/cloneOracle.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/destroyClone/destroyClone.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/restoreOracle/restoreOracle.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x backupNow.py
chmod +x cloneOracle.py
chmod +x destroyClone.py
chmod +x restoreOracle.py
# End Download Commands
```

Please review the README for each:

* restoreOracle: <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/restoreOracle>
* cloneOracle: <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/cloneOracle>
* destroyClone: <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/destroyClone>
* backupNow: <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/backupNow>
