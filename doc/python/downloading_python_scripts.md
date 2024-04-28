# How to Download These Python Scripts

The README.md for each script provides download commands that you can run from a linux terminal. For example, to download the backupNow.py script:

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/backupNow/backupNow.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x backupNow.py
# End download commands
```

* The first command downloads backupNow.py
* The second downloads pyhesity.py (function library required by the python scripts in this repository)
* The third command grants execute permissions to backupNow.py

If the curl commands don't work, it's likely because the linux terminal does not have access to the Internet, or perhaps access to GitHub is blocked. In this case, you can manually copy/paste the scripts, using the following process:

To get pyhesity.py:

1. On your laptop (where Internet access is possible), open your web browser and go to <https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py>
2. Select all and copy the contents to your clipboard
3. On the linux host, type `vi pyhesity.py`
4. Type `i` (for insert)
5. Paste the contents from the clipboard
6. Type `:` then type `wq` (write, quit)

To get backupNow.py:

1. On your laptop (where Internet access is possible), open your web browser and go to <https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/backupNow/backupNow.py>
2. Select all and copy the contents to your clipboard
3. On the linux host, type `vi backupNow.py`
4. Type `i` (for insert)
5. Paste the contents from the clipboard
6. Type `:` then type `wq` (write, quit)
7. Type `chmod +x backupNow.py` (to grant execute permissions)
