#!/usr/bin/env python
"""Backup Strike Report v3.0"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True, action='append')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str)
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-dy', '--days', type=int, default=31)

args = parser.parse_args()

vips = args.vip
username = args.username
domain = args.domain
password = args.password
folder = args.outfolder
days = args.days
useApiKey = args.useApiKey

for vip in vips:

    # authenticate
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

    print('Collecting report data for %s...' % vip)

    cluster = api('get', 'cluster')

    title = 'Backup Strike Report (%s)' % cluster['name']
    now = datetime.now()
    date = now.strftime("%m/%d/%Y %H:%M:%S")
    datestring = now.strftime("%Y-%m-%d")
    htmlfileName = '%s/%s-%s-strikeReport.html' % (folder, datestring, cluster['name'])
    csvfileName = '%s/%s-%s-strikeReport.csv' % (folder, datestring, cluster['name'])
    csv = codecs.open(csvfileName, 'w', 'utf-8')

    html = '''<html>
    <head>
        <style>
            p {
                color: #555555;
                font-family:Arial, Helvetica, sans-serif;
            }
            span {
                color: #555555;
                font-family:Arial, Helvetica, sans-serif;
            }

            table {
                font-family: Arial, Helvetica, sans-serif;
                color: #333333;
                font-size: 0.75em;
                border-collapse: collapse;
                width: 100%;
            }

            tr {
                border: 1px solid #F1F1F1;
            }

            td,
            th {
                text-align: left;
                padding: 6px;
            }

            tr:nth-child(even) {
                background-color: #F1F1F1;
            }
        </style>
    </head>
    <body>

        <div style="margin:15px;">
                <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAARgAAAAoCAMAAAASXRWnAAAC8VBMVE
                WXyTz///+XyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
                yXyTyXyTyXyTyXyTwJ0VJ2AAAA+nRSTlMAAAECAwQFBgcICQoLDA0ODxARExQVFhcYGRobHB0eHy
                EiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj9AQUNERUZHSElKS0xNTk9QUVJTVFVWV1hZWl
                tcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9foCBgoOEhYaHiImKi4yNjo+QkZKTlJ
                WWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc
                7Q0dLT1NXW19jZ2tvc3d7f4OHi4+Xm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+drbbjAAACOZJRE
                FUaIHtWmlcVUUUv6alIgpiEGiZZIpiKu2i4obhUgipmGuihuZWiYmkRBu4JJVappaG5VJRUWrllq
                ZWivtWVuIWllHwShRI51PvnjP33pk7M1d579Gn/j8+zDnnf2b5v3tnu2g1/ocUmvuPRasx83cVu1
                zFB5endtWUCHgoM/+0y1V64sOZcXVlhMDpWXdLM+PmPnmdZTVJeLCPiL6Jd9jT6nfo2y+hH4vE/h
                Fcj6bP6uhcqxvxfYzOdsxOb6gYm39qdrRmE6bBxB2EQWHOXfLBvVvMsIqWdBEYzYvcgWRJ6nS3f5
                +/YSWXEQVeYJPqpXx5XkaaalFuOu22h2E5UVkrIadaAyXFXTwbKh1cw0J3bCgvzFO/CRWtuk3IjP
                lKYK23C7ga3IFCblPwp1HrNvUAyH1W0tRzKlIbk/OmbpbX04uNHGp1/9j6MxMMxUNSYXbqoTJWmF
                t3yCqqHGVLzJK2l8qTtoOzldBqD/C/Ra3hDgOYZKTU2awmpZgVbwG7udWGEvovHYXFHIkuYzHECN
                Pzb0VNy9g8/60KVh5X/QbwtRCajQH//GsQ5k7KCTzqQGprVrwW7HC9GOKQQMhpP30UpWiIM0XYZQ
                gcsYR50Mo9vj73vS9+sOy1Vl6A5S7auXJ53v4Lpr2Trf9LcN0utNsZ/K9Ra4iy++XGE+h3zGGQaV
                bFn+n2lWZQ7q/6id04iW/fI2idFTp4CAOdTWHuNFWZQCf7luMOGr4e9jxCXu1WBxw3Ja03XJs8FG
                ZFdBcbusY2NRKM2k9mD32oXwKLxIGRTMWsMFpon14PAGKTynX/9z17ot27Z23KxyeMLLT1bw6hHT
                SECaTLTOWUmgxt3B/ofcxwLKfdXM2+JH0MtTI8E2aqwLLQDWsuH3+9A0kHJwwDWKC2ifwAF9Z8L+
                dtj87TmikMnTkONOfTg/PAHU7NUVSBQbZWcqjf2vhURZiXHMZ7BBi/RzhQEAphQi7q/l2ShA7Y5S
                L2QdDOoDPSFCYBHQfF3+UZQlwDaDkAJybSSWBl0FZMh4+EuRcIl8Qtg4AqC6NlY58/Zlyvo2uaZg
                rzEz6wN0ryWyY2tlU1TML6CENDDdtHwswCQpqaYKLqwmg/Y5/7mo5O6Niil1GYOPQMkOab8MMN5Q
                fSIO5Mjxumj4T5To+X3gDlsUuXvQV4e0nOyEg70wNhInDUZfWp7Y8rbBnsy1EYnKI3SdMt4AxDu2
                kHfRmjqekbYWrrBwuSD+V3CIc9k7jJwRNhtCewqnXUpAtgHBggjP8l8EQpO4hYB6xsRfQ4ROdQyz
                fChELHZuvFaGLHsWiW6okwdBtKEsHoj8YKDIEwuLf7Udk/RL2/FINFPAbRvdTyjTA3/6PHM/Vioi
                AMITMYqkfCNMDJ4aJ+mgwAJjlXC0MgTKbjo2AAd/OHVeHQSj1cQedvFKamwGoqEeYpZZMBJXp8iV
                4MPCNR5mWL6pEwWi9i/pybsWgcS0GYfHD1V/YPMQZYi5Vx3HLcjwYKk9I7nkdcmkSY9x/gSQnx5j
                r4ox7HQ3D4nkvlFwEXyk1lzJ2nh8JouVjP49pELEw2AiDMCfDdp8xGzASWeun8AOIJrDAqXO2sdC
                GeEnAXQG+tQpuEAUIad3/uF8ps4qUw1+NqWjIEp9lvzAAIg5NHc2U2Yh6wRirj8yE+2hfCkMtBSB
                hh664JP9zhkI2Gw0NhtPvZZisamX4QBtbvypvV2YDFkPuIMj4X4mPR8FIY0h4J9XGvLbs3GY9EYx
                fuqTBaGtMqs5GzhLlytX03PhGPKuOvQNw3T0ypselagPYrkvbwNVtBLY+F0faYra5mvCAMvrD3OG
                W78TywnlbGcQf2MBreCfOzeRprUIGeYynCmx4Ac/B5uvJ5LkzoFdrqSdYLwuC14NVWJZy31avStx
                DvgAYKM6pbLx5dpkiEWdqmPYeoqFpWrb1NtY4fPAQ4fHQb3g+tAXekt8Jow2gD3EUsCIPTqtPp3+
                qi/ALZjbowhVcGs8KIp4dmEmGmOTb7hOyRAjUmQJE+ol4IQzs7l/OBMDj3H3XO1kJwIgxXhHGvdI
                Bry/v7GDcmS4RZpAf6QjEZWd4Ikw4VDeZ8IEwTbK2dczoedUmWIsrL7kNhtO7M9TMF3EjGQ5HuH7
                wRBpf+8ZwPT9c4Ma+/SgfxNsol7vN1tMYeGx8DfSmMdl1GoU0Y2LjjS0Z3lN4IM1spDL6t9MCtxK
                3IypUG4TMVKTRMnwqjabV6ZeVtK9i9S0fBnny8QsXTPl2tqkcYnDit3QOLO1KHG0V6TTdQwkrFUL
                Jh+1gYGfA8eoZa1SOMfrOr4zsxKcnt/pyWW9AHub3AisXAb6bjPxBmMyQvpVY1CUPPUmSD/Wszbp
                jHUGsRsspibawkqlhv01P9wryITRq3a9UkjHlBVsR9GemAM4e1Vza+IOWwAoYto97Zlq8qwjzj3G
                0pwldikysNR3UJo42mgyNfD6pDY7F5hs88OQZXUs/5LGM/E5ljfKXdztRbFWFyAkPsaOxvpQS1im
                jBITxiaO4/2OSVgGoXRnvZUIH8smHetPR566wlcpXFjzGdZO+KjKmZq8zPuOSon4fCVJSU2VHx60
                wjI6OEqGEdY6pPGC1T1Tq3V+5UqmBtYXWh18yiMDGcMMMUdekYgpQRDhT2UhQ/dCiE2X0twkxQCa
                MNKJY1XtyPr+WWDdI+PsuztoGztdAHXL6WUGukw6ALkPKJmnF5OFPxRnAJv0QYuA/Y3TwW2FW2Ca
                OFrRFbXxMm1PP0nwJrXw8bB7/RiF82W4LfOFa0dRDmDaTMVRK2cv+nh10X/oXLD64sdzgLg2eleM
                5n+x+8Tu9wg3Yt6yyrqFH6Ea6LXyQJFFjlMiW5S93+YlPsl5TDPkbHGLxfGi7J58ehtdO9MzQBcN
                HXXaEIRZB+GCvgv9sL/7UZNGjhzlMlLtefhdsXDG6kqRCd9tnh8y5X6dmC3NHS83a73LX2/4lATN
                64iLlEjZk8aaIETyZb3Rw9Y3oah/Rp42KDhHqj3v18hKy9AZ+u6Sjzs6g/e1NGbd5Vo8a/916SKO
                8LK0YAAAAASUVORK5CYII=" style="width:180px">
            <p style="margin-top: 15px; margin-bottom: 15px;">
                <span style="font-size:1.3em;">'''

    html += title
    html += '''</span>
    <span style="font-size:1em; text-align: right; padding-top: 8px; padding-right: 2px; float: right;">'''
    html += date
    html += '''</span>
    </p>
    <table>
    <tr>
        <th>Object Name</th>
        <th>Type</th>
        <th>Job Name</th>
        <th>Failure Count</th>
        <th>Last Good Backup</th>
        <th>Error Message</th>
    </tr>'''

    csv.write('Object Name,Type,Job Name,Failure Count,Last Good Backup,Error Message\n')

    objectStatus = {}
    totalObjects = 0

    print('getting runs...')
    allruns = api('get', 'protectionRuns?excludeTasks=true&startTimeUsecs=%s&numRuns=999999' % timeAgo(31, 'days'))
    print('getting jobs...')
    jobs = api('get', 'protectionJobs?allUnderHierarchy=true&isActive=true&includeLastRunAndStats=true')

    for job in sorted(jobs, key=lambda job: job['name'].lower()):
        print("  %s" % job['name'])
        if 'lastRun' in job:
            startTimeUsecs = job['lastRun']['backupRun']['stats']['startTimeUsecs']
            for source in job['lastRun']['backupRun']['sourceBackupStatus']:
                totalObjects += 1
                sourcename = source['source']['name']
                if source['status'] not in ['kSuccess', 'kWarning']:
                    sourceType = source['source']['environment']
                    if sourceType == 'kPuppeteer':
                        sourceType == 'kView'
                    search = api('get', '/searchvms?vmName=%s&entityTypes=%s&allUnderHierarchy=true&jobIds=%s' % (sourcename, sourceType, job['id']))
                    if 'vms' in search:
                        latestSnapshotUsecs = search['vms'][0]['vmDocument']['versions'][0]['instanceId']['jobStartTimeUsecs']
                        errorRuns = [run for run in allruns if run['jobId'] == job['id'] and run['backupRun']['stats']['startTimeUsecs'] > latestSnapshotUsecs]
                    else:
                        errorRuns = [run for run in allruns if run['jobId'] == job['id'] and run['backupRun']['stats']['startTimeUsecs'] > (timeAgo(31, 'days'))]
                        latestSnapshotUsecs = 0
                    if errorRuns:
                        numErrors = len(errorRuns)
                        if source['status'] != 'kFailure':
                            numErrors -= 1
                    else:
                        numErrors = '-'
                    thisStatus = {'objectName': sourcename,
                                  'status': source['status'],
                                  'jobName': job['name'],
                                  'jobId': job['id'],
                                  'jobType': source['source']['environment'],
                                  'startTimeUsecs': startTimeUsecs,
                                  'latestSnapshotUsecs': latestSnapshotUsecs,
                                  'numErrors': numErrors}
                    if 'error' in source:
                        thisStatus['message'] = source['error']
                    else:
                        thisStatus['message'] = ''
                    if numErrors != 0 and (sourcename not in objectStatus or startTimeUsecs > objectStatus[sourcename]['startTimeUsecs']):
                        objectStatus[sourcename] = thisStatus

    for entity in objectStatus:
        if objectStatus[entity]['latestSnapshotUsecs'] == 0:
            lastSuccess = '-'
        else:
            lastSuccess = usecsToDate(objectStatus[entity]['latestSnapshotUsecs'])
        row = '''<tr>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                </tr>''' % (entity, objectStatus[entity]['jobType'], objectStatus[entity]['jobName'], objectStatus[entity]['numErrors'], lastSuccess, objectStatus[entity]['message'][:99])
        html += row
        csv.write('"%s","%s","%s","%s","%s","%s"\n' % (entity, objectStatus[entity]['jobType'], objectStatus[entity]['jobName'], objectStatus[entity]['numErrors'], lastSuccess, objectStatus[entity]['message'][:99]))
    totalFailedObjects = len(objectStatus)
    if totalObjects != 0:
        percentFailed = round((100 * (float(totalObjects - totalFailedObjects)) / float(totalObjects)), 2)
    else:
        percentFailed = 0

    html += '''</table>
    <p style="margin-top: 15px; margin-bottom: 15px;"><span style="font-size:1em;">%s protected objects failed out of %s total objects (%s%% success rate)</span></p>
    </div>
    </body>
    </html>
    ''' % (totalFailedObjects, totalObjects, percentFailed)

    print('saving report as %s' % htmlfileName)
    print('also saving as %s' % csvfileName)

    f = codecs.open(htmlfileName, 'w', 'utf-8')
    f.write(html)
    f.close()
    csv.close()
