#!/usr/bin/env python
"""Cohesity Python REST API Wrapper Module - v1.7 - Brian Seltzer - July 2018"""

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

import datetime, json, requests, getpass, os
from os.path import expanduser

### ignore unsigned certificates
import requests.packages.urllib3
requests.packages.urllib3.disable_warnings()

__all__ = ['apiauth', 'api', 'usecsToDate', 'dateToUsecs', 'timeAgo', 'dayDiff', 'display']

APIROOT = ''
HEADER = ''
AUTHENTICATED = False
APIMETHODS = ['get', 'post', 'put', 'delete']
CONFIGDIR = expanduser("~") + '/.pyhesity'

### authentication
def apiauth(vip, username, domain='local', updatepw=None):
    """authentication function"""
    global APIROOT
    APIROOT = 'https://' + vip + '/irisservices/api/v1'
    creds = json.dumps({"domain": domain, "password": __getpassword(vip, username, domain, updatepw), "username": username})
    global HEADER
    HEADER = {'accept': 'application/json', 'content-type': 'application/json'}
    url = APIROOT + '/public/accessTokens'
    response = requests.post(url, data=creds, headers=HEADER, verify=False)
    if response != '':
        if response.status_code == 201:
            accessToken = response.json()['accessToken']
            tokenType = response.json()['tokenType']
            HEADER = {'accept': 'application/json', \
                      'content-type': 'application/json', \
                      'authorization': tokenType + ' ' + accessToken}
            global AUTHENTICATED
            AUTHENTICATED = True
            print "Connected!"
        else:
            response.raise_for_status()

### api call function
def api(method, uri, data=''):
    """api call function"""
    if AUTHENTICATED == False:
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
        if response != '':
            if response.status_code == 204:
                return ''
            if response.status_code == 404:
                return 'Invalid api call: ' + uri
            responsejson = response.json()
            if 'errorCode' in responsejson:
                if 'message' in responsejson:
                    print '\033[93m' + responsejson['errorCode'][1:] + ': ' + responsejson['message'] + '\033[0m'
                else:
                    print responsejson
                return ''
            else:
                return responsejson
    else:
        print "invalid api method"

### convert usecs to date
def usecsToDate(uedate):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = uedate/1000000
    return datetime.datetime.fromtimestamp(uedate).strftime('%Y-%m-%d %H:%M:%S')

### convert date to usecs
def dateToUsecs(datestring):
    """Convert Date String to Unix Epoc Microseconds"""
    dt = datetime.datetime.strptime(datestring, "%Y-%m-%d %H:%M:%S")
    msecs = int(dt.strftime("%s"))
    usecs = msecs*1000000
    return usecs

### convert date difference to usecs
def timeAgo(timedelta,timeunit):
    """Convert Date Difference to Unix Epoc Microseconds"""
    now = int(datetime.datetime.now().strftime("%s"))*1000000
    secs = {'seconds': 1, 'sec': 1, 'secs': 1, \
            'minutes': 60, 'min': 60, 'mins': 60, \
            'hours': 3600, 'hour': 3600, \
            'days': 86400, 'day': 86400, \
            'weeks': 604800, 'week': 604800, \
            'months': 2628000, 'month': 2628000, \
            'years': 31536000, 'year': 31536000 }
    age = int(timedelta) * int(secs[timeunit.lower()]) * 1000000
    return now - age

def dayDiff(newdate,olddate):
    """Return number of days between usec dates"""
    print newdate
    print olddate
    return int(round((newdate - olddate) / float(86400000000)))

### get/store password for future runs
def __getpassword(vip, username, domain, updatepw):
    """get/set stored password"""
    pwpath = os.path.join(CONFIGDIR, 'lt.' + vip + '.' + username + '.' + domain)
    if(updatepw == 'updatepw'):
        if(os.path.isfile(pwpath) == True):
            os.remove(pwpath)
    try:
        pwdfile=open(pwpath,'r')
        pwd=''.join(map(lambda num: chr(int(num)-1), pwdfile.read().split(',')))
        pwdfile.close()
        return pwd
    except:
        pwd="1"
        pwd2="2"
        while (pwd <> pwd2):
            pwd=getpass.getpass("Enter your password: ")
            pwd2=getpass.getpass("Confirm your password: ")
            if(pwd <> pwd2):
                print "Passwords do not match. Try again:"
        pwdfile=open(pwpath,'w')
        pwdfile.write(','.join(str(char) for char in list(map(lambda char: ord(char)+1, pwd))))
        pwdfile.close()
        return pwd

### display json/dictionary as formatted text 
def display (myjson):
    """pretty print dictionary"""
    if(isinstance(myjson,list)):
        #handle list of results
        for result in myjson:
            print json.dumps(result, sort_keys=True, indent=4, separators=(',', ': '))
    else:
        #or handle single result
        print json.dumps(myjson, sort_keys=True, indent=4, separators=(',', ': '))

### create CONFIGDIR if it doesn't exist
if os.path.isdir(CONFIGDIR) == False:
    os.mkdir(CONFIGDIR)