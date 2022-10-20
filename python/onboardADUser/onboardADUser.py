#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)          # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')  # admin user to do the work
parser.add_argument('-d', '--domain', type=str, default='local')     # domain of admin user
parser.add_argument('-i', '--useApiKey', action='store_true')        # use API key for authentication
parser.add_argument('-p', '--password', type=str, default=None)      # password for admin user
parser.add_argument('-n', '--aduser', type=str, required=True)       # AD user to onboard
parser.add_argument('-a', '--addomain', type=str, required=True)     # AD user to onboard
parser.add_argument('-desc', '--description', type=str, default='')  # AD user description
parser.add_argument('-keyname', '--keyname', type=str, default='')      # API key name
parser.add_argument('-r', '--role', type=str, default='COHESITY_VIEWER')    # Cohesity role to grant
parser.add_argument('-g', '--generateApiKey', action='store_true')          # generate new API key
parser.add_argument('-s', '--storeApiKey', action='store_true')             # store API key in file
parser.add_argument('-o', '--overwrite', action='store_true')               # overwrite existing API key

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
aduser = args.aduser
addomain = args.addomain
description = args.description
keyname = args.keyname
role = args.role
generateApiKey = args.generateApiKey
storeApiKey = args.storeApiKey
overwrite = args.overwrite

# authenticate
apiauth(vip, username, domain, password=password, useApiKey=useApiKey)

# get users
users = [user for user in api('get', 'users') if user['username'].lower() == aduser.lower() and user['domain'].lower() == addomain.lower()]
if len(users) == 0:
    # add user
    newUserParams = [
        {
            "principalName": aduser,
            "objectClass": "kUser",
            "roles": [
                role
            ],
            "domain": addomain,
            "restricted": False,
            "description": description
        }
    ]
    print('Granting role: %s to user %s/%s...' % (role, addomain, aduser))
    newuser = api('post', 'activeDirectory/principals', newUserParams)
    users = [user for user in api('get', 'users') if user['username'].lower() == aduser.lower() and user['domain'].lower() == addomain.lower()]
else:
    print('User %s/%s already on board...' % (addomain, aduser))

# generate API Key
if generateApiKey:
    sid = users[0]['sid']
    if keyname == '':
        keyname = '%s-key' % users[0]['username']

    keys = [key for key in api('get', 'usersApiKeys') if key['name'].lower() == keyname]
    if len(keys) > 0:
        if overwrite is True:
            deletekey = api('delete', 'users/%s/apiKeys/%s' % (sid, keys[0]['id']))
        else:
            print('api key already exists for %s' % username)
            exit(1)
    params = {
        'isActive': True,
        'user': users[0],
        'name': keyname
    }

    response = api('post', 'users/%s/apiKeys' % sid, params)

    if 'key' in response:
        if storeApiKey is True:
            setpwd(v=vip, u=aduser, d=addomain, password=response['key'], useApiKey=True)
        else:
            print('New API Key: %s' % response['key'])
    else:
        display(response)
