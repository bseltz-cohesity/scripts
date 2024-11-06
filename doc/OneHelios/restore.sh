#!/bin/bash

##########################################
#
# OneHelios Restore - version  2024.11.06a
# Last Updated By: Brian Seltzer
#
##########################################

LOG_FILE='restore-log.txt'
RESTORE_SET_FILE='restore-set-name.txt'
CATALOG=0
RESTORE_POSTGRES=0
RESTORE_MONGODB=0
RESTORE_ELASTIC=0
DO_ALL=0
ELASTIC_BACKUP_REPOSITORY='elastic-restores-repo'

function usage {
    programname=$0
    cat <<HELP_USAGE
    usage: $programname [-acemp] [-s set_name] [-k key_name]"
        -a          (restore all services - the default)
        -c          (display catalog)
        -l          (display log from backup set)
        -e          (restore Elasticsearch)
        -m          (restore MongoDB)
        -p          (restore Postgres)
        -s set_name (name of backup set - required when performing restores)
        -k key_name (arbitrary key name to restore - emits value to STDOUT)
HELP_USAGE
    exit 1
}

while getopts "clpmeas:k:" flag
    do
        case "${flag}" in
            c) CATALOG=1;;
            l) GETLOG=1;;
            p) RESTORE_POSTGRES=1;;
            m) RESTORE_MONGODB=1;;
            e) RESTORE_ELASTIC=1;;
            s) SET_NAME=${OPTARG};;
            k) KEY_NAME=${OPTARG};;
            a) DO_ALL=1;;
            *) usage | tee $LOG_FILE; exit 1;;
        esac
    done

if [ -z "${POSTGRES_RW_SERVICE_HOST}" ]; then
    POSTGRES_RW_SERVICE_HOST="$POSTGRES_SERVICE_HOST"
fi

if [ -z "${RESTORE_S3_HOST}" ] || [ -z "${RESTORE_S3_ACCESS_KEY}" ] || [ -z "${RESTORE_S3_SECRET_KEY}" ] || [ -z "${RESTORE_S3_LOCATION}" ] || [ -z "${RESTORE_S3_BUCKET}" ] || [ -z "${ELASTIC_BACKUP_REPOSITORY}" ]
then
    echo -e " ** Environment is not set! **" | tee $LOG_FILE
    exit 1
fi

echo '' > $LOG_FILE

# create elastic backup repo
REPO_RESULT=$(curl -X 'GET' "http://$ELASTICSEARCH_ES_HTTP_SERVICE_HOST:$ELASTICSEARCH_ES_HTTP_SERVICE_PORT/_snapshot" 2>dev/null)
if [[ "$REPO_RESULT" != *$ELASTIC_BACKUP_REPOSITORY* ]]; then
    echo -e "\n -- Creating Elastic Snapshot Repository\n" | tee -a $LOG_FILE
    curl -X PUT -k \
        --url "http://$ELASTICSEARCH_ES_HTTP_SERVICE_HOST:$ELASTICSEARCH_ES_HTTP_SERVICE_PORT/_snapshot/$ELASTIC_BACKUP_REPOSITORY" \
        -H 'Content-type: application/json' \
        -d '{
        "type": "s3",
        "settings": {
            "bucket": "'${RESTORE_S3_BUCKET}'",
            "access_key": "'${RESTORE_S3_ACCESS_KEY}'",
            "secret_key": "'${RESTORE_S3_SECRET_KEY}'",
            "endpoint": "'${RESTORE_S3_HOST}'",
            "readonly": "true",
            "path_style_access": "true",
            "protocol": "https"
        }
    }' 2>/dev/null | tee -a $LOG_FILE
fi

if [[ $CATALOG -eq 1 ]]; then

    echo -e "\nBACKUP DATE       SET NAME                        CONTENTS" | tee -a $LOG_FILE
    echo -e "----------------  ------------------------------  ---------" | tee -a $LOG_FILE

    s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate ls s3://$RESTORE_S3_BUCKET/BACKUP_SETS/ | while read -r line; do
        lineparts=($line)
        BACKUP_DATE="${lineparts[0]} ${lineparts[1]}"
        S3_PATH=${lineparts[3]}
        arr=(${S3_PATH//\// })
        SET_NAME=${arr[3]}
        MONGO_PRESENT=''
        POSTGRES_PRESENT=''
        ELASTIC_PRESENT=''
        THIS_LOG=$(s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate get $S3_PATH -)
        if [[ $THIS_LOG == *"Mongo backup verified"* ]] || [[ $THIS_LOG == *"MongoDB backup succeeded"* ]]; then
            MONGO_PRESENT=' MONGODB'
        fi
        if [[ $THIS_LOG == *"Postgres backup verified"* ]] || [[ $THIS_LOG == *"Postgres backup succeeded"* ]]; then
            POSTGRES_PRESENT=' POSTGRES'
        fi
        if [[ $THIS_LOG == *"Elastic backup verified"* ]] || [[ $THIS_LOG == *"Elastic backup succeeded"* ]]; then
            ELASTIC_PRESENT=' ELASTIC'
        fi
        CONTENTS="${MONGO_PRESENT}${POSTGRES_PRESENT}${ELASTIC_PRESENT}"
        if [[ $CONTENTS == '' ]]; then
            CONTENTS=' ** FAILED **'
        fi
        echo "$BACKUP_DATE  $SET_NAME $CONTENTS" | tee -a $LOG_FILE
    done
    echo ""
    exit 0
fi

if [[ -z $KEY_NAME ]] && [[ $RESTORE_POSTGRES -eq 0 ]] && [[ $RESTORE_MONGODB -eq 0 ]] && [[ $RESTORE_ELASTIC -eq 0 ]]; then
    DO_ALL=1
fi
if [[ $DO_ALL -eq 1 ]]; then
    RESTORE_POSTGRES=1
    RESTORE_MONGODB=1
    RESTORE_ELASTIC=1
fi

if [ -z "${SET_NAME}" ]
then
    echo -e " ** SET_NAME required **" | tee -a $LOG_FILE
    exit 1
fi

if [[ $GETLOG -eq 1 ]]; then
    s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate --quiet get s3://$RESTORE_S3_BUCKET/BACKUP_SETS/$SET_NAME 2>/dev/null
    echo ""
    cat $SET_NAME
    rm $SET_NAME
exit
fi

if [[ -z $KEY_NAME ]]
then
    echo -e "\n -- Restoring from backup set: $SET_NAME\n" | tee -a $LOG_FILE
fi

RESTORE_STATUS='Success'
RESTORE_EXIT_CODE=0

# restore mongodb
if [[ $RESTORE_MONGODB -eq 1 ]]; then
    MONGO_DUMP=$(s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate ls s3://$RESTORE_S3_BUCKET/DUMPS/$SET_NAME/mongodump)
    if [[ $MONGO_DUMP != '' ]]; then
        echo -e " -- Restoring MongoDB\n" | tee -a $LOG_FILE
        s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate get s3://$RESTORE_S3_BUCKET/DUMPS/$SET_NAME/mongodump - | mongorestore $MONGODB_CONNECT_STRING --username=$MONGODB_USER --password=$MONGODB_PASSWORD --nsExclude="admin.*" --nsExclude="dev-mongo-keyknox.secrets" --drop --archive | tee -a $LOG_FILE
        # s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate get s3://$RESTORE_S3_BUCKET/DUMPS/$SET_NAME/mongodump - | mongorestore $MONGODB_CONNECT_STRING --username=$MONGODB_USER --password=$MONGODB_PASSWORD --drop --archive | tee -a $LOG_FILE
        MONGO_STATUS=$?
        if [[ $MONGO_STATUS -ne 0 ]]; then
            echo -e '\n ** MongoDB restore failed! **\n' | tee -a $LOG_FILE
            RESTORE_STATUS='Failure'
            RESTORE_EXIT_CODE=1
        else
            echo -e "\n -- MongoDB restore succeeded\n" | tee -a $LOG_FILE
        fi
    else
        echo -e " ** No MongoDB dump in backup set $SET_NAME **\n" | tee -a $LOG_FILE
        RESTORE_STATUS='Failure'
        RESTORE_EXIT_CODE=1
    fi
fi

# restore postgres
if [[ $RESTORE_POSTGRES -eq 1 ]]; then
    POSTGRES_DUMP=$(s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate ls s3://$RESTORE_S3_BUCKET/DUMPS/$SET_NAME/pgdump)
    if [[ $POSTGRES_DUMP != '' ]]; then
        echo -e " -- Dropping Postgres databases\n" | tee -a $LOG_FILE
        psql -h $POSTGRES_RW_SERVICE_HOST -U $POSTGRES_USER -w -c "COPY (SELECT datname FROM pg_database WHERE datistemplate=false) TO STDOUT;" | while read -r line; do
            lineparts=($line)
            DB_NAME="${lineparts[0]}"
            if [[ $DB_NAME != 'postgres' ]]; then
                echo "    Dropping database: $DB_NAME"  | tee -a $LOG_FILE
                psql -h $POSTGRES_RW_SERVICE_HOST -U $POSTGRES_USER -w -c 'DROP DATABASE "'$DB_NAME'" WITH (FORCE);;' >/dev/null 2>&1
            fi
        done
        echo -e " -- Restoring Postgres\n" | tee -a $LOG_FILE
        s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate get s3://$RESTORE_S3_BUCKET/DUMPS/$SET_NAME/pgdump - | grep -v 'ALTER ROLE postgres' | psql -h $POSTGRES_RW_SERVICE_HOST -U $POSTGRES_USER -w # | tee -a $LOG_FILE
        PG_STATUS=$?
        if [[ $PG_STATUS -ne 0 ]]; then
            echo -e '\n ** Postgres restore failed! **\n' | tee -a $LOG_FILE
            RESTORE_STATUS='Failed'
            RESTORE_EXIT_CODE=2
        else
            echo -e "\n -- Postgres restore succeeded\n" | tee -a $LOG_FILE
        fi
    else
        echo -e " ** No Postgres dump in backup set $SET_NAME **\n" | tee -a $LOG_FILE
        RESTORE_STATUS='Failure'
        RESTORE_EXIT_CODE=2
    fi
fi

# restore elastic
if [[ $RESTORE_ELASTIC -eq 1 ]]; then
    echo -e " -- Restoring Elastic\n" | tee -a $LOG_FILE
    # confirm snapshot exists
    SNAPSHOT_RESULT=$(curl -X 'GET' "http://$ELASTICSEARCH_ES_HTTP_SERVICE_HOST:$ELASTICSEARCH_ES_HTTP_SERVICE_PORT/_snapshot/$ELASTIC_BACKUP_REPOSITORY/$SET_NAME" 2>dev/null | jq -r '.snapshots[0].state')
    if [[ $SNAPSHOT_RESULT == 'SUCCESS' ]]; then
        # drop existing indices
        curl -X 'GET' "http://$ELASTICSEARCH_ES_HTTP_SERVICE_HOST:$ELASTICSEARCH_ES_HTTP_SERVICE_PORT/_cat/indices" 2>/dev/null | while read -r line; do
            lineparts=($line)
            INDEX_NAME="${lineparts[2]}"
            echo "    Dropping index: $INDEX_NAME" | tee -a $LOG_FILE
            curl -X 'DELETE' "http://$ELASTICSEARCH_ES_HTTP_SERVICE_HOST:$ELASTICSEARCH_ES_HTTP_SERVICE_PORT/$INDEX_NAME" >/dev/null 2>&1
        done
        # perform restore
        echo "    Restoring indices" | tee -a $LOG_FILE
        ELASTIC_RESULT=$(curl -X 'POST' "http://$ELASTICSEARCH_ES_HTTP_SERVICE_HOST:$ELASTICSEARCH_ES_HTTP_SERVICE_PORT/_snapshot/$ELASTIC_BACKUP_REPOSITORY/$SET_NAME/_restore?wait_for_completion=true" 2>/dev/null)
        ELASTIC_STATUS=$?
        echo -e "$ELASTIC_RESULT" | tee -a $LOG_FILE
        if [[ $ELASTIC_STATUS -ne 0 ]]; then
            echo -e " ** Elastic restore failed! **" | tee -a $LOG_FILE
            RESTORE_STATUS='Failed'
            RESTORE_EXIT_CODE=3
        else
            ELASTIC_SUCCESS=$(echo $ELASTIC_RESULT | jq -r '.snapshot.shards.failed')
            if [[ $ELASTIC_SUCCESS -eq 0 ]]; then
                echo -e "\n -- Elastic restore succeeded\n" | tee -a $LOG_FILE
            else
                echo -e "\n ** Elastic restore failed! **\n" | tee -a $LOG_FILE
                RESTORE_STATUS='Failed'
                RESTORE_EXIT_CODE=3
            fi
        fi
    else
        echo -e " ** No Elastic snapshot in backup set $SET_NAME **\n" | tee -a $LOG_FILE
        RESTORE_STATUS='Failed'
        RESTORE_EXIT_CODE=3
    fi
fi

## restore key/value
if [ -z "${KEY_NAME+x}" ]
then
    true
else
    KEY_VALUE=$(s3cmd --host=$RESTORE_S3_HOST --access_key=$RESTORE_S3_ACCESS_KEY --secret_key=$RESTORE_S3_SECRET_KEY --region=$RESTORE_S3_LOCATION --no-check-certificate get s3://$RESTORE_S3_BUCKET/DUMPS/$SET_NAME/$KEY_NAME - 2>/dev/null)
    if [[ $KEY_VALUE != '' ]]; then
        echo $KEY_VALUE
        exit 0
    else
        exit 1
    fi
fi

echo -e " -- Exiting with RESTORE_EXIT_CODE: $RESTORE_EXIT_CODE ($RESTORE_STATUS)\n" | tee -a $LOG_FILE
exit $RESTORE_EXIT_CODE
