# Install the Python Requests Module without Internet Access

If your system does not have access to the Internet, you can get a tgz of the requests module and its dependencies here:

For RHEL 9 and other platforms running Python 3.9.x:

<https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/requests-3.9.18.tgz>

For RHEL 8 and other platforms running Python 3.6.x:

<https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/requests-3.6.8.tgz>

Transfer and tar-unzip the package on you system, then cd into the folder with the extracted files, and you can use the pip (or pip3) to install the modules.

For RHEL 9 and other platforms running Python 3.9.x:

```bash
pip3 install requests-2.31.0-py3-none-any.whl  -f ./ --no-index
```

For RHEL 8 and other platforms running Python 3.6.x:

```bash
pip3 install requests-2.27.1-py2.py3-none-any.whl -f ./ --no-index
```
