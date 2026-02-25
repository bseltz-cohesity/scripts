# How to Use API Keys for Helios Authentication

When connecting to Helios, we use API Key authentication. Here's how to create and use a Helios API Key.

## Create an API Key

Log into Helios with your web broswer, then:

1. Go to Settings -> Access Management -> API Keys
2. Click Add API Key
3. Enter an arbitrary name for your new API Key
4. Click Save

You will have one chance to copy or download the new API key (it will not be visible again once you navigate away from the page). Once you have created your API key, you can use the API Key for authentication. For example:

## Using an API Key for Authentication

When using an API key, there is no need to acquire an access token nor session ID. You simply add a header to your requests:

```bash
apiKey: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

With this header set, you can make API calls without any further authentication. An example curl command:

```bash
curl -X GET "https://helios.cohesity.com/v2/mcm/cluster-config/clusters" \
     -H "apiKey: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
     -H "accept: application/json"
```
