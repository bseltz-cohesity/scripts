# Install the Python Requests Module without Internet Access

If your system does not have access to the Internet, you can get a tgz or zip of the requests module and its dependencies here:

tgz: <https://github.com/bseltz-cohesity/scripts/raw/master/python/requests.tgz>

or

zip: <https://github.com/bseltz-cohesity/scripts/raw/master/python/requests.zip>

Transfer and unzip the package on you system, then cd into the folder with the extracted files, and you can use the pip (or pip3) to install the modules.

```bash
pip3 install requests-2.31.0-py3-none-any.whl  -f ./ --no-index
```
