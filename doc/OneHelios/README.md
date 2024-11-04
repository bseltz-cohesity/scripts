# OneHelios Backup Service

## Table of Contents

1. [Requirements](#Requirements)
2. [Create an S3 View](#S3View)
3. [Backup Configuration and Testing](#Backup)
4. [Schedule Backups](#Schedule)
5. [Restore](#Restore)
6. [Build or Upgrade the Backup Service Image](#Upgrades)

<a name="Requiremnts" id="Requirements"></a>

## Requirements

* S3 Target - an S3 compatible object storage bucket. This can be an S3 view on a Cohesity cluster, an S3 bucket in AWS, etc.
* Access Key and Secret Key to access the bucket

<a name="S3View" id="S3View"></a>

## Create an S3 View on a Cohesity Cluster

On a Cohesity cluster that can be reached over the network by the OneHelios appliance, create an S3 View:

* Log onto the Cohesity cluster using an account that has the right to create Views
* Click SmartFiles -> Views -> Create View
* Select the template: Object Services -> General
* Enter the name of the view (this will be the S3 bucket name)
* Click More Options
* Expand the Security section
* Click Global Subnet Allowlist -> Add
* Add the subnet of the OneHelios cluster nodes (e.g. 10.1.1.0/24) with Read/Write permissions and click Add or,
* Add IP address of each node (e.g. 10.1.1.20/32) with Read/Write permissions and click Add (repeat for each node)
* Click Create

### S3 Hostname and Port

When using a Cohesity view as the S3 bucket, the s3 host will be cluster.fqdn:3000 (e.g. mycluster.mydomain.net:3000) or cluster.IPaddress:3000 (e.g. 10.1.1.100:3000)

### Access Key and Secret Key

The S3 View created above will only have one user in the ACL: the user that created the view. So, use that user's the access key and secret key in the configurations below. To get the keys:

* Log onto the Cohesity cluster
* Click Settings -> Access Management
* Click on the user that created the S3 view
* Copy the Access Key ID and the Secret Access Key to paste into the configurations below

<a name="Backup" id="Backup"></a>

## Backup Configuration and Testing

Setup requires intervention by support, who will need to enable host shell access to the OneHelios appliance so that we can SSH into it.

```bash
ssh support@myappliance -p 2222
sudo su - cohesity
```

### Create Backup Configuration

Now we must create a file backup-config.yaml. Example:

```yaml
apiVersion: v1
stringData:
  accesskey: MY_ACCESS_KEY_xHAcEUiSJYc3irjlWVc1mF2vjdCYh
  secretkey: MY_SECRET_KEY_1fNMPao-D7ht6lOcz9I0Rh6dqQksR
  host: 10.1.1.100:3000
  bucket: OneHelios
  location: US
  retention: "7"
  appliance-name: "onehelios"
  smtp-server: "smtp.mydomain.net"
  smtp-port: "25"
  smtp-user: ""
  smtp-password: ""
  smtp-from: "from@cohesity.com"
  smtp-to: "to@cohesity.com"
kind: Secret
metadata:
  creationTimestamp: null
  name: backup-config
```

Populate the backup-config.yaml file with the appropriate values:

* accesskey: access Key to access the S3 bucket
* secretkey: secret Key to access the S3 bucket
* host: host where S3 bucket is located (use host:port format for non-standard port)
* bucket: name of S3 bucket
* location: region name for AWS, otherwise this is ignored
* retention: number of days to retain backups
* appliance-name: name of OneHelios appliance (used in email subject)
* smtp-server: SMTP relay to send email through
* smtp-port: SMTP port (usually port 25)
* smtp-user: SMTP user if credentials are required (otherwise leave as "")
* smtp-password: SMTP password if credentials are required (otherwise leave as "")
* smtp-from: email address to send from
* smtp-to: email address to send to

Once complete, apply the yaml to Kubernetes:

```bash
kubectl apply -f backup-config.yaml -n cohesity-onehelios-onehelios
```

<a name="Test" id="Test"></a>

### Launch the Backup-service Pod

Find the backup-service.yaml file and apply it to Kubernetes:

```bash
kubectl apply -f backup-service.yaml -n cohesity-onehelios-onehelios
```

Then exec into the pod:

```bash
kubectl exec --stdin --tty -n cohesity-onehelios-onehelios backup-service -- /bin/bash
```

### Test Access to S3

You can test access to your S3 bucket using the command:

```bash
s3cmd --host=$S3_HOST --access_key=$S3_ACCESS_KEY --secret_key=$S3_SECRET_KEY ls s3://$S3_BUCKET --no-check-certificate
```

`Note`: if this is your first test, the bucket will be empty, so no items will be returned, but if no error is shown, then access is working.

### Run a Test Backup

Now at the bash prompt inside the pod, we can test the backup:

```bash
./backup.sh
```

Most issues will be caused by incorrect settings in backup-config.yaml. Review and fix any settings, and if any changes are made, re-apply and restart:

```bash
kubectl apply -f backup-config.yaml -n cohesity-onehelios-onehelios
kubectl delete pod backup-service -n cohesity-onehelios-onehelios
kubectl apply -f backup-service.yaml -n cohesity-onehelios-onehelios
```

Then exec into the pod and test again:

```bash
kubectl exec --stdin --tty -n cohesity-onehelios-onehelios backup-service -- /bin/bash
```

```bash
./backup.sh
```

Once the backup is working as expected we can shutdown the pod:

```bash
kubectl delete pod backup-service -n cohesity-onehelios-onehelios
```

### Backup Options

By default, all services are backed up. You can add parameters to backup specific services:

```text
    usage: ./backup.sh [-aemnpx] [-t to_address] [-s set_name] [-k key_name] [-v key_value]
        -a            (backup all services - the default)
        -e            (backup Elasticsearch)
        -m            (backup MongoDB)
        -n            (do not send email report)
        -p            (backup Postgres)
        -x            (expire old backups)
        -t to_address (email address to send report to)
        -s set_name   (name of backup set - auto generated by default)
        -k key_name   (arbitrary key name to store)
        -v key_value  (arbitrary value to store for key name)
```

<a name="Schedule" id="Schedule"></a>

## Schedule Backups Using a Cron Job

Review the backup-cronjob.yaml file:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "0 */12 * * *"
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 7
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      backoffLimit: 0
      ttlSecondsAfterFinished: 86400
      template:
        spec:
          containers:
          - name: backup-service
            image: backup-service
            imagePullPolicy: Never
            command:
            - /bin/bash
            - -c
            - /backup.sh
            ... (more not shown)
```

Modify the schedule to specify the frequency of backups. The schedule is defined in CRON format. The example above backs up every 12 hours.

Also note the backoffLimit. By default it is set to zero (no retries after a backup failure). If you prefer to have it retry after a failure, increase the number.

Also review the command. If you need to pass any command line arguments to the script, append them to the command. for example, to disable email reports add the `-n` switch:

```yaml
            command:
            - /bin/bash
            - -c
            - /backup.sh -n
```

After saving any changes, apply to Kubernetes:

```bash
kubectl apply -f backup-cronjob.yaml -n cohesity-onehelios-onehelios
```

Now the backup should run on schedule.

### Test the Cron Job

To trigger the cronjob:

```bash
kubectl create job --from=cronjob/backup backuptest1 -n cohesity-onehelios-onehelios
```

### Review the Jobs and Logs

After the schedule has been triggered, You can review logs from completed backups:

```bash
kubectl get jobs -n cohesity-onehelios-onehelios
kubectl logs job.batch/backuptest1 -n cohesity-onehelios-onehelios
```

<a name="Restore" id="Restore"></a>

## Restore

To restore, we create a restore configuration that points to the S3 bucket where the backups are located.

### Create Restore Configuration

Now we must create a file restore-config.yaml. Example:

```yaml
apiVersion: v1
stringData:
  accesskey: MY_ACCESS_KEY_xHAcEUiSJYc3irjlWVc1mF2vjdCYh
  secretkey: MY_SECRET_KEY_1fNMPao-D7ht6lOcz9I0Rh6dqQksR
  host: 10.1.1.100:3000
  bucket: OneHelios
  location: US
kind: Secret
metadata:
  creationTimestamp: null
  name: restore-config
```

Populate the yaml file with the appropriate values:

* Access Key to access the S3 bucket
* Secret Key to access the S3 bucket
* host where S3 bucket is located (use host:port format for non-standard port)
* Bucket name
* location (region name for AWS, otherwise this is ignored)

Once complete, apply the yaml to Kubernetes:

```bash
kubectl apply -f restore-config.yaml -n cohesity-onehelios-onehelios
```

Start the backup-service pod:

```bash
kubectl apply -f backup-service.yaml -n cohesity-onehelios-onehelios
```

Then exec into the pod:

```bash
kubectl exec --stdin --tty -n cohesity-onehelios-onehelios backup-service -- /bin/bash
```

To see the catalog of available backups run the restore script with the -c switch:

```bash
./restore.sh -c
```

Output should look like this:

```text
BACKUP DATE       SET NAME                        CONTENTS
----------------  ------------------------------  ---------
2024-10-24 12:00  1729771201.2024-10-24_12:00:01  MONGODB POSTGRES ELASTIC
2024-10-24 12:05  1729771512.2024-10-24_12:05:12  MONGODB POSTGRES ELASTIC
2024-10-24 12:23  1729772556.2024-10-24_12:22:36  MONGODB POSTGRES ELASTIC
2024-10-24 13:38  1729777061.2024-10-24_13:37:41  MONGODB POSTGRES ELASTIC
2024-10-24 16:54  1729788794.2024-10-24_16:53:14  MONGODB POSTGRES ELASTIC
2024-10-24 21:22  1729804904.2024-10-24_21:21:44  MONGODB POSTGRES ELASTIC
2024-10-25 00:00  1729814401.2024-10-25_00:00:01  MONGODB POSTGRES ELASTIC
2024-10-25 04:00  1729828801.2024-10-25_04:00:01  MONGODB POSTGRES ELASTIC
2024-10-25 08:00  1729843201.2024-10-25_08:00:01  MONGODB POSTGRES ELASTIC
2024-10-25 09:15  1729847662.2024-10-25_09:14:22  MONGODB POSTGRES ELASTIC
```

To review the backup log from a specific backup set, specify the set name and use the -l option:

```bash
./restore.sh -s 1729847662.2024-10-25_09:14:22 -l
```

To restore from a backup set, specify the set name:

```bash
./restore.sh -s 1729847662.2024-10-25_09:14:22
```

After restore is complete, shut down the pod:

```bash
kubectl delete pod backup-service -n cohesity-onehelios-onehelios
```

### Restore Options

By default, all services will be restored. You can add parameters to restore specific services:

```text
    usage: ./restore.sh [-acemp] [-s set_name] [-k key_name]"
        -a          (restore all services - the default)
        -c          (display catalog)
        -l          (display log from backup set)
        -e          (restore Elasticsearch)
        -m          (restore MongoDB)
        -p          (restore Postgres)
        -s set_name (name of backup set - required when performing restores)
        -k key_name (arbitrary key name to restore - emits value to STDOUT)
```

<a name="Upgrades" id="Upgrades"></a>

## Build or Upgrade the Backup Service Image

If an updated version of the backup service is required, you can ask Cohesity Support for an updated image, or use docker to build the image.

### Build the Image Using Docker

You will need the following files to build the image (these files are provided in this repository):

* [backup.sh](https://raw.githubusercontent.com/cohesity/community-automation-samples/refs/heads/main/doc/OneHelios/backup.sh)
* [restore.sh](https://raw.githubusercontent.com/cohesity/community-automation-samples/refs/heads/main/doc/OneHelios/restore.sh)
* [Dockerfile](https://raw.githubusercontent.com/cohesity/community-automation-samples/refs/heads/main/doc/OneHelios/Dockerfile)
* [Dockerfile-base](https://raw.githubusercontent.com/cohesity/community-automation-samples/refs/heads/main/doc/OneHelios/Dockerfile-base)

Place these files together in one directory, then build and save the image:

If you don't already have the base image `alpine-cohesity-slim`:

```bash
docker build -f Dockerfile-base -t alpine-cohesity-slim .
```

then build the `backup-service` image:

```bash
docker build -t backup-service .
docker image save backup-service > backup-service.tar
```

### Import the Updated Image

1. Ask Cohesity Support to enable host shell access to the OneHelios appliance
2. scp the image to a node of the appliance:

```bash
scp -P 2222 backup-service.tar support@10.140.246.4:
```

3. ssh into the node

```bash
ssh support@10.140.246.4 -p 2222
```

4. Move the file and set permissions

```bash
sudo mv backup-service.tar /home/cohesity
sudo chown cohesity:cohesity /home/cohesity/backup-service.tar
```

5. Distribute and load the image

```bash
sudo su - cohesity
allscp.sh backup-service.tar /home/cohesity/backup-service.tar
allssh.sh "sudo nerdctl -n k8s.io load -i /home/cohesity/backup-service.tar"
```

6. Test the backup ([See above](#Test))
