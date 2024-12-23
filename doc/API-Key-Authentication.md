# How to Enable and Use API Keys for Authentication

Scripts don't support SSO authentication. Although MFA is supported with scripts, since the MFA code changes frequently, it can not be used for scheduled/unattended script execution. We can avoid these problems by using API Key authentication.

## Make the API Keys Page Visible in the Cohesity UI (Temporary)

By default, API Key management is not visible in the Cohesity UI. To make it visible temporarily (for you current web browser session):

1. Log into the Cohesity UI (directly to the cluster, not via Helios) as an admin user
2. In the address bar, enter the url: <https://mycluster/feature-flags>
3. In the field provided, type: api
4. Turn on the toggle for apiKeysEnabled

## Make the API Keys Page Visible in the Cohesity UI (Permanant)

To make the API Key management page visible permanently, ask Cohesity support to help you set the iris gflag:

```bash
# enable API Keys UI feature
iris_ui_flags: apiKeysEnabled=true
# note: iris must be stopped and started for the changes to take effect
```

## Create an API Key

Now that the API Key management page is visible, to create yourself an API key:

Remember that you must log into the Cohesity cluster UI directly, not via Helios, in order to see the API Keys page.

1. Go to Settings -> Access Management -> API Keys
2. Click Add API Key
3. Select the user to associate the new API key
4. Enter an arbitrary name
5. Click Add

You will have one chance to copy or download the new API key (it will not be visible again once you navigate away from the page). Once you have created your API key, you can use the -useApiKey parameter of the script to make use of API key authentication. For example:

## Using an API Key for Authentication

When using an API key, there is no need to acquire an access token nor session ID. You simply add a header to your requests:

```bash
apiKey: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

With this header set, you can make API calls without any further authentication. An example curl command:

```bash
curl -X GET "https://mycluster/irisservices/api/v1/public/cluster" \
     -H "apiKey: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
     -H "accept: application/json"
```

## Using an API Key in BSeltz Scripts

```powershell
# example using API key authentication
.\backupNow.ps1 -vip mycluster `
                -username myuser `
                -jobName myjob `
                -useApiKey
# end example
```

When prompted for a password, enter the API key (instead of a password). Or, you can provide the API key via the command line using the -pwd parameter:

```powershell
# example using API key authentication
.\backupNow.ps1 -vip mycluster `
                -username myuser `
                -jobName myjob `
                -useApiKey `
                -pwd xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# end example
```

Here's a Python example:

```bash
# example using API key authentication
./backupNow.py -v mycluster \
               -u myuser \
               -j myjob \
               -i \
               -p xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# end example
```
