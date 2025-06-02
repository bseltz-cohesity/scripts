# Requirements for Running Cohesity Python Scripts

## Network Accessibility to the Cohesity Cluster (or to Helios)

For scripts that connect to a Cohesity cluster (or to helios.cohesity.com), the script must be able to:

* Resolve the IP address used in the -v (--vip) parameter
* Reach the cluster via port 443/tcp (network routes and firewalls must not block this traffic)
* Be allowed access by the Cohesity cluster firewall (see Settings -> Networking -> Firewall -> Management in the Cohesity UI)

The script may appear to "hang" if traffic is blocked (it will eventually time out and report an error). Depending on the operating system and python version, error messages may vary, but errors will mention timeout, SSL, connection, retries. These errors almost never have anything to do with the script, nor anything requiring Cohesity support. Contact your own network team to verify connectivity between the script host and the Cohesity cluster (or helios.cohesity.com), and Contact your Cohesity administrator to check the Cohesity firewall rules.

To check if the cluster is accessible, if the script host has a web browser, simply point the web browser to <https://mycluster> to see if you can get to the Cohesity UI. If the Cohesity UI does not appear, the above requirements are not met.

If there is no web browser, you can use the curl command:

```bash
curl -k https://mycluster
```

Curl should output HTML code (returned from the cluster). If curl produces an error, then the above requirements are not met.

## Python Version

You can run these python scripts using any version of Python that is new enough to support TLSv1.2 encryption (2.7 or later, plus some later versions of 2.6.x). The only additional requirement that is widely used in these scripts is the python "requests" module.

## Requests Module

The requests module is not a built-in module (it does not come with the default python installation). If you try to run one of these scripts and you see the below error, then the requests module is not installed and you need to install it:

```text
No module named 'requests'
```

To install the requests module, depending on your operating system and python version, you can try some of the commands listed below:

### Linux and MacOS

If you have pip installed (pip is the package installer for python and should come by default with your python installation):

```bash
sudo pip install requests
# or
sudo pip3 install requests
# or
python -m pip install requests
# or
python3 -m pip install requests
```

Alternatively if you have the `easy_install` utility installed:

```bash
sudo easy_install -U requests
```

### Linux Package Managers

Alternatively you can use your linux package manager:

Using yum:

```bash
sudo yum install python-requests
# or
sudo yum install python3-requests
```

Using dnf:

```bash
sudo dnf install python-requests
# or
sudo yum install python3-requests
```

Using apt-get (Ubuntu, Debian):

```bash
sudo apt-get install python-requests
# or
sudo apt-get install python3-requests
```

### Windows

```bash
pip install requests
# or
pip3 install requests
# or
python -m pip install requests
# or
python3 -m pip install requests
```

## Install the Python Requests Module without Internet Access

If your system does not have access to the Internet, you can get a tgz of the requests module and its dependencies here:

For RHEL 9 and other platforms running Python 3.9.x:

<https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/requests-3.9.18.tgz>

For RHEL 8 and other platforms running Python 3.6.x:

<https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/requests-3.6.8.tgz>

Transfer and tar-unzip the package on you system, then cd into the folder with the extracted files, and you can use the pip (or pip3) to install the modules.

For RHEL 9 and other platforms running Python 3.9.x:

```bash
pip3 install requests-2.31.0-py3-none-any.whl  -f ./ --no-index
```

For RHEL 8 and other platforms running Python 3.6.x:

```bash
pip3 install requests-2.27.1-py2.py3-none-any.whl -f ./ --no-index
```

## Running Scripts

Each script in this repository provides a README that explains the command line options and provides one or more examples.

The python examples assume that you are running the script on a Linux, MacOS or other non-Windows system where the python scripts are directly executable, for example:

```bash
./myscript.py -v mycluster -u myuser
```

The above will only work if the commmand `/usr/bin/env python` launches python. If it does not, then simply add `python` or `python3` to the beginning of the command, like:

```bash
python3 ./myscript.py -v mycluster -u myuser
```

Or on a Windows system:

```bash
python3 myscript.py -v mycluster -u myuser
```
