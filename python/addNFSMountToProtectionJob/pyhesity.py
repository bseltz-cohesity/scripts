#!/usr/bin/env python
"""Cohesity Python REST API Wrapper Module - v2.0 - Brian Seltzer - Mar 2019"""

##########################################################################################
# Change Log
# ==========
#
# 1.1 - added encrypted password storage - August 2017
# 1.2 - added date functions and private api access - April 2018
# 1.3 - simplified password encryption (weak!) to remove pycrypto dependency - April 2018
# 1.4 - improved error handling, added display function - May 2018
# 1.5 - added no content return - May 2018
# 1.6 - added dayDiff function - May 2018
# 1.7 - added password update feature - July 2018
# 1.8 - added support for None JSON returned - Jan 2019
# 1.9 - supressed HTTPS warning in Linux and PEP8 compliance - Feb 2019
# 1.9.1 - added support for interactive password prompt - Mar 2019
# 2.0 - python 3 compatibility - Mar 2019
#
##########################################################################################
# Install Notes
# =============
#
# Requires module: requests
# sudo easy_install requests
#         - or -
# sudo yum install python-requests
#
##########################################################################################

import datetime
import json
import requests
import getpass
import os
import urllib3
from os.path import expanduser

### ignore unsigned certificates
import requests.packages.urllib3
requests.packages.urllib3.disable_warnings()

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

__all__ = ['apiauth', 'api', 'usecsToDate', 'dateToUsecs', 'timeAgo', 'dayDiff', 'display']

APIROOT = ''
HEADER = ''
AUTHENTICATED = False
APIMETHODS = ['get', 'post', 'put', 'delete']
CONFIGDIR = expanduser("~") + '/.pyhesity'


### authentication
def apiauth(vip, username, domain='local', password=None, updatepw=None, prompt=None, quiet=None):
    """authentication function"""
    global APIROOT
    APIROOT = 'https://' + vip + '/irisservices/api/v1'
    creds = json.dumps({"domain": domain, "password": __getpassword(vip, username, password, domain, updatepw, prompt), "username": username})
    global HEADER
    HEADER = {'accept': 'application/json', 'content-type': 'application/json'}
    url = APIROOT + '/public/accessTokens'
    response = requests.post(url, data=creds, headers=HEADER, verify=False)
    if response != '':
        if response.status_code == 201:
            accessToken = response.json()['accessToken']
            tokenType = response.json()['tokenType']
            HEADER = {'accept': 'application/json',
                      'content-type': 'application/json',
                      'authorization': tokenType + ' ' + accessToken}
            global AUTHENTICATED
            AUTHENTICATED = True
            if(quiet is None):
                print("Connected!")
        else:
            print(response.json()['message'])


### api call function
def api(method, uri, data=None):
    """api call function"""
    if AUTHENTICATED is False:
        return "Not Connected"
    response = ''
    if uri[0] != '/':
        uri = '/public/' + uri
    if method in APIMETHODS:
        if method == 'get':
            response = requests.get(APIROOT + uri, headers=HEADER, verify=False)
        if method == 'post':
            response = requests.post(APIROOT + uri, headers=HEADER, json=data, verify=False)
        if method == 'put':
            response = requests.put(APIROOT + uri, headers=HEADER, json=data, verify=False)
        if method == 'delete':
            response = requests.delete(APIROOT + uri, headers=HEADER, json=data, verify=False)
        if isinstance(response, bool):
            return ''
        if response != '':
            if response.status_code == 204:
                return ''
            # if response.status_code == 404:
            #     return 'Invalid api call: ' + uri
            responsejson = response.json()
            if isinstance(responsejson, bool):
                return ''
            if responsejson is not None:
                if 'errorCode' in responsejson:
                    if 'message' in responsejson:
                        print('\033[93m' + responsejson['errorCode'][1:] + ': ' + responsejson['message'] + '\033[0m')
                    else:
                        print(responsejson)
                    # return ''
                # else:
                return responsejson
    else:
        print("invalid api method")


### convert usecs to date
def usecsToDate(uedate):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = uedate / 1000000
    return datetime.datetime.fromtimestamp(uedate).strftime('%Y-%m-%d %H:%M:%S')


### convert date to usecs
def dateToUsecs(datestring):
    """Convert Date String to Unix Epoc Microseconds"""
    dt = datetime.datetime.strptime(datestring, "%Y-%m-%d %H:%M:%S")
    msecs = int(dt.strftime("%s"))
    usecs = msecs * 1000000
    return usecs


### convert date difference to usecs
def timeAgo(timedelta, timeunit):
    """Convert Date Difference to Unix Epoc Microseconds"""
    now = int(datetime.datetime.now().strftime("%s")) * 1000000
    secs = {'seconds': 1, 'sec': 1, 'secs': 1,
            'minutes': 60, 'min': 60, 'mins': 60,
            'hours': 3600, 'hour': 3600,
            'days': 86400, 'day': 86400,
            'weeks': 604800, 'week': 604800,
            'months': 2628000, 'month': 2628000,
            'years': 31536000, 'year': 31536000}
    age = int(timedelta) * int(secs[timeunit.lower()]) * 1000000
    return now - age


def dayDiff(newdate, olddate):
    """Return number of days between usec dates"""
    return int(round((newdate - olddate) / float(86400000000)))


### get/store password for future runs
def __getpassword(vip, username, password, domain, updatepw, prompt):
    """get/set stored password"""
    if password is not None:
        return password
    if prompt is not None:
        pwd = getpass.getpass("Enter your password: ")
        return pwd
    pwpath = os.path.join(CONFIGDIR, 'lt.' + vip + '.' + username + '.' + domain)
    if(updatepw is not None):
        if(os.path.isfile(pwpath) is True):
            os.remove(pwpath)
    try:
        pwdfile = open(pwpath, 'r')
        pwd = ''.join(map(lambda num: chr(int(num) - 1), pwdfile.read().split(', ')))
        pwdfile.close()
        return pwd
    except Exception:
        pwd = getpass.getpass("Enter your password: ")
        pwdfile = open(pwpath, 'w')
        pwdfile.write(', '.join(str(char) for char in list(map(lambda char: ord(char) + 1, pwd))))
        pwdfile.close()
        return pwd


### display json/dictionary as formatted text
def display(myjson):
    """prettyprint dictionary"""
    if(isinstance(myjson, list)):
        # handle list of results
        for result in myjson:
            print(json.dumps(result, sort_keys=True, indent=4, separators=(', ', ': ')))
    else:
        # or handle single result
        print(json.dumps(myjson, sort_keys=True, indent=4, separators=(', ', ': ')))


### create CONFIGDIR if it doesn't exist
if os.path.isdir(CONFIGDIR) is False:
    os.mkdir(CONFIGDIR)
