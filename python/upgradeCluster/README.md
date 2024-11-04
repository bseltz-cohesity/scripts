# Upgrade a Cohesity Cluster using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script initiates an upgrade of a Cohesity cluster to a newer version.

## Components

* [upgradeCluster.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/upgradeCluster/upgradeCluster.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): Cohesity REST API helper module

## Optional Components

* [upgradeServer.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/upgradeCluster/upgradeServer.py): lightweight web server for hosting upgrade files
* cohesity-upgradeserver.service systemd-unit file to run upgradeServer as a daemon

## Download the Files

Run the following commands to download the scripts:

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/upgradeCluster/upgradeCluster.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/upgradeCluster/upgradeServer.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/upgradeCluster/cohesity-upgradeserver.service
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/upgradeCluster/testupgrade.sh
chmod +x upgradeCluster.py
chmod +x upgradeServer.py
chmod +x testupgrade.sh
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -r, --release': e.g. '6.6.0d_u6_release-20221204_c03629f0'
* -url, --url': e.g. '<http://192.168.1.195:5000/6.6.0d_u6_release-20221204_c03629f0>'

## Hosting the upgrade files

Cohesity provides upgrade packages that can be downloaded at <http://downloads.cohesity.com/downloads>

During a cluster upgrade, you can enter the URL of an upgrade package in the Cohesity UI and the cluster will download and install the upgrade package. The cluster can download the upgrade package directly from the Cohesity download site, or you can host the upgrade package on your own web server.

Hosting the upgrade packages on your own web server is beneficial especially if your Cohesity clusters can not reach the public Internet, or if you have many Cohesity clusters and you do not want to drag multi-GB upgrade packages repeatedly over your Internet connection.

For convenience, I've included a lightweight web server (written in python of course), called upgradeServer.py, but really any web server that can host files for download will suffice.

## Deploying the Upgrade Server (Optional)

upgradeServer.py uses Flask (a web services framework for python) which can be installed on really any python platform using the command: `pip install Flask`

The following instructions are for deploying upgradeServer.py on CentOS 7 Linux.

On a Linux host, install Flask:

```bash
sudo yum install python-flask
sudo firewall-cmd --zone=public --permanent --add-port 5000/tcp
sudo firewall-cmd --reload
```

Then make a directory for the upgrade server:

```bash
sudo mkdir -p /opt/cohesity/upgradeserver
```

And copy `upgradeServer.py` into that directory and make it executable (e.g. `chmod +x upgradeServer.py`)

Next, copy the `cohesity-upgradeserver.service` file to `/lib/systemd/system`

From within the upgrade server directory, download at least one upgrade package:

```bash
cd /opt/cohesity/upgradeserver
curl -O https://www.downloads.cohesity.com/artifacts/6.6.0d_u6/20221205-020056/release_full/tar/cohesity-6.6.0d_u6_release-20221204_c03629f0.tar.gz
```

Now let's edit the upgradeServer.py.

```python
#!/usr/bin/env python

from flask import Flask, send_file

app = Flask(__name__)
app.debug = True


@app.route('/6.6.0d_u6_release-20221204_c03629f0', methods=['GET'])
def download660d():
    return send_file('cohesity-6.6.0d_u6_release-20221204_c03629f0.tar.gz', as_attachment=True)


@app.route('/', methods=['GET'])
def rootpage():
    return '''
<h2>Cohesity Upgrade Server</h2>
<br/>
<a href='6.6.0d_u6_release-20221204_c03629f0'>6.6.0d_u6_release-20221204_c03629f0</a><br/>
'''


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, threaded=True)
```

As you can see, for each upgrade package that we want to host, we have a stanza (each of which begins with `@app.route`). Add, change or remove these stanzas depending on what upgrade package you wish to host.

Also near the bottom of the script, edit the `href` lines. These will appear when opening the upgradeServer url in a browser.

Finally, enable and start the upgradeServer:

```bash
systemctl enable cohesity-upgradeserver.service
systemctl start cohesity-upgradeserver.service
```

In my case, I've deployed the upgradeServer on a linux host with the IP address of 192.168.1.195, so my upgrade url is <http://192.168.1.195:5000> (Flask uses port 5000 by default). If I append a release to the url, the file will begin to download <http://192.168.1.195:5000/6.6.0d_u6_release-20221204_c03629f0>

## Upgrading a Cluster

Now that you've got your upgrade files hosted on your web server (or decided not to do this), we can upgrade a cluster, like so:

```bash
./upgradeCluster.py -v 192.168.1.194 -u admin -r '6.6.0d_u6_release-20221204_c03629f0' -url 'http://192.168.1.195:5000/6.6.0d_u6_release-20221204_c03629f0'
```

or if you've decided not to deploy an upgrade server, you can access the upgrade package directly from the Cohesity download site:

```bash
./upgradeCluster.py -v 192.168.1.194 -u admin -r '6.6.0d_u6_release-20221204_c03629f0' -url 'https://www.downloads.cohesity.com/artifacts/6.6.0d_u6/20221205-020056/release_full/tar/cohesity-6.6.0d_u6_release-20221204_c03629f0.tar.gz'
```

the script should return a message like this:

```text
Connected!
Request to upgrade the S/W version of the cluster to 6.6.0d_u6_release-20221204_c03629f0 is accepted
```
