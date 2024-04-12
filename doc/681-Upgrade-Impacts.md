# 6.8.1 Upgrade Impacts

## Multi-Factor Authentication

In 6.8.1 it has become mandatory to enable multi-factor authentication (MFA) for Active Directory users added to Cohesity. This is to guard against hacked AD accounts being used in a cyber attack. When authenticating through the Cohesity REST API, if MFA is enabled, the MFA OTP code must be sent with the authentication request, or authentication will fail.

In the current release of the script libraries (cohesity-api.ps1 and pyhesity.py), if the required MFA code is omitted, an error will be reported: `"Authentication failed: MFA Code Required"`. In older versions, a less helpful error message was reported: `"Please specify the mandatory parameters"`. In this case, you must use the -mfaCode paramter of the script, for example:

```powershell
.\backupNow.ps1 -vip mycluster -username myuser -jobName myjob -mfaCode 123456
```

Most recently released scripts have this -mfaCode parameter. If you find an older script where the -mfaCode parameters is not present, please ask to have the script updated.

Since the MFA code changes frequently, it can not be used for scheduled/unattended script execution. In this case, we can avoid MFA by using API Key authentication.

## API Key Authentication

By default, API Key management is not visible in the Cohesity UI. To make it visible temporarily (for you current web browser session):

1. Log into the Cohesity UI (directly to the cluster, not via Helios) as an admin user
2. In the address bar, enter the url: <https://mycluster/feature-flags>
3. In the field provided, type: api
4. Turn on the toggle for apiKeysEnabled

To make the API Key management page visible permanently, ask Cohesity support to help you set the iris gflag:

```bash
iris_ui_flags: apiKeysEnabled=true
# note: iris must be stopped and started for the changes to take effect
```

Now that the API Key management page is visible, to create yourself an API key:

1. Go to Settings -> Access Management -> API Keys
2. Click Add API Key
3. Select the user to associate the new API key
4. Enter an arbitrary name
5. Click Add

You will have one chance to copy or download the new API key (it will not be visible again once you navigate away from the page). Once you have created your API key, you can use the -useApiKey parameter of the script to make use of API key authentication. For example:

```powershell
.\backupNow.ps1 -vip mycluster -username myuser -jobName myjob -useApiKey
```

When prompted for a password (or specifying the password on the command line), enter the API key instead of a password.

## API Rate Limiting

6.8.1 also introduced stricter API rate limits, to guard against denial of service attacks. These limits are generally tolerable except when some scripts are used that make many API calls in rapid succession. When running such scripts, if you recieve errors such as `"Too many requests"`, you should first consider whether the script could be modified to make fewer API calls, but if that's not possible, ask Cohesity support to help you adjust the rate limits using the following iris gflag:

```bash
iris_throttling_requests_per_second: 2000 (default is 600)
# note: iris must be stopped and started for the changes to take effect
```

## API Timeouts

On a large, busy Cohesity cluster, API response times can increase, especially if you are making a lot of API calls related to backup/restore operations. In extreme cases (when thousands of API calls are being made per minute), response times can grow to several minutes. If the response time is too long, you may receive errors like `"Operation timed out"`. In this case you can increase the iris timeout gflags:

```bash
iris_post_timeout_msecs_to_magneto: 300000 (default is 180000)
iris_read_timeout_msecs_to_magneto: 300000 (default is 180000)
# note: iris must be stopped and started for the changes to take effect
```
