# Protecting O365 Objects with PowerShell

There are some special considerations when protecting O365 objects on a large scale. Many customers have thousands of user mailbox, Onedrive, Public Folder, Sharepoint, Team objects, etc. When creating protection groups for these objects, the number of objects protected by each group should be limited to 5000.

If you have more than 5000 of a specific object type (mailboxes for example), you should create multiple protection groups, each containing up to 5000 mailboxes, with the last protection group set to autoprotect and excluding the mailboxes protected by the other groups.

This can be done using the protectO365 scripts for:

* Mailboxes: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Mailboxes>
* Onedrive: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365OneDrive>
* Public Folders: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365PublicFolders>
* Sharepoint Sites: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Sites>
* Teams: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Teams>

For example, if you have 12000 mailboxes to protect, you can create two groups with 5000 each, plus a third group that uses autoprotect and excludes the 10000 mailboxes protected by the other groups, thus protecting the last 2000. This autoprotect group will automatically protect any new mailboxes that are created in the future.

To set this up using the protectO365Mailboxes.ps1 script, you can run the script three times like so:

```powershell
# protect 5000 mailboxes
./protectO365Mailboxes.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -jobName 'o365 mailboxes 1' `
                           -policyName mypolicy `
                           -sourceName 'myaccount.onmicrosoft.com' `
                           -allMailboxes

# protect another 5000 mailboxes
./protectO365Mailboxes.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -jobName 'o365 mailboxes 2' `
                           -policyName mypolicy `
                           -sourceName 'myaccount.onmicrosoft.com' `
                           -allMailboxes

# autoprotect remaining 2000 mailboxes and any future mailboxes
./protectO365Mailboxes.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -jobName 'o365 mailboxes 3' `
                           -policyName mypolicy `
                           -sourceName 'myaccount.onmicrosoft.com' `
                           -autoProtectRemaining
```

If you have 17000 mailboxes, you would add another run of the script to protect another 5000 mailboxes before creating the autoprotect group:

```powershell
# protect 5000 mailboxes
./protectO365Mailboxes.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -jobName 'o365 mailboxes 1' `
                           -policyName mypolicy `
                           -sourceName 'myaccount.onmicrosoft.com' `
                           -allMailboxes

# protect another 5000 mailboxes
./protectO365Mailboxes.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -jobName 'o365 mailboxes 2' `
                           -policyName mypolicy `
                           -sourceName 'myaccount.onmicrosoft.com' `
                           -allMailboxes

# protect another 5000 mailboxes
./protectO365Mailboxes.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -jobName 'o365 mailboxes 3' `
                           -policyName mypolicy `
                           -sourceName 'myaccount.onmicrosoft.com' `
                           -allMailboxes

# autoprotect remaining 2000 mailboxes and any future mailboxes
./protectO365Mailboxes.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -jobName 'o365 mailboxes 4' `
                           -policyName mypolicy `
                           -sourceName 'myaccount.onmicrosoft.com' `
                           -autoProtectRemaining
```
