#!/bin/bash
# Stash/Bitbucket Backup script
# Started 2/2/2016 Alex Merenyi for CVENT

# Adapted from Atlassian, https://confluence.atlassian.com/bitbucketserver/using-bitbucket-server-diy-backup-776640056.html

# Database team is managing database backups, thus we need only concern ourselves with the Filesystem backups. 
# Backing up Stash is a four-step job: initial backup, lock, backup, and unlock.
# This script will perform an inital Rsync, lock the Stash instance, drain the database and SCM connections, perform a secondary Rsync, and unlock.

STASH_URL="https://staging-stash/"


# Our breakout/print error function.
function bail {
    error $*
    exit 99
}

# Our order is:
STASH_INITIAL_BACKUP()
STASH_LOCK()
stash_backup_start()



STASH_HTTP_AUTH="-u ${STASH_BACKUP_USER}:${STASH_BACKUP_PASS}"
 
function stash_lock {
    STASH_LOCK_RESULT=`curl -s -f ${STASH_HTTP_AUTH} -X POST -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance/lock"`
    if [ -z "${STASH_LOCK_RESULT}" ]; then
        bail "Locking this Stash instance failed"
    fi
 
    STASH_LOCK_TOKEN=`echo ${STASH_LOCK_RESULT} | jq -r ".unlockToken"`
    if [ -z "${STASH_LOCK_TOKEN}" ]; then
        bail "Unable to find lock token. Result was '$STASH_LOCK_RESULT'"
    fi
 
    info "locked with '$STASH_LOCK_TOKEN'"
}

function stash_backup_start {
    STASH_BACKUP_RESULT=`curl -s -f ${STASH_HTTP_AUTH} -X POST -H "X-Atlassian-Maintenance-Token: ${STASH_LOCK_TOKEN}" -H "Accept: application/json" -H "Content-type: application/json" "${STASH_URL}/mvc/admin/backups?external=true"`
    if [ -z "${STASH_BACKUP_RESULT}" ]; then
        bail "Entering backup mode failed"
    fi
 
    STASH_BACKUP_TOKEN=`echo ${STASH_BACKUP_RESULT} | jq -r ".cancelToken"`
    if [ -z "${STASH_BACKUP_TOKEN}" ]; then
        bail "Unable to find backup token. Result was '${STASH_BACKUP_RESULT}'"
    fi
 
    info "backup started with '${STASH_BACKUP_TOKEN}'"
}

function stash_backup_wait {
    STASH_PROGRESS_DB_STATE="AVAILABLE"
    STASH_PROGRESS_SCM_STATE="AVAILABLE"
 
    print -n "[${STASH_URL}] .INFO: Waiting for DRAINED state "
    while [ ${STASH_PROGRESS_DB_STATE} != "DRAINED" -a ${STASH_PROGRESS_SCM_STATE} != "DRAINED" ]; do
        print -n "."
 
        STASH_PROGRESS_RESULT=`curl -s -f ${STASH_HTTP_AUTH} -X GET -H "X-Atlassian-Maintenance-Token: ${STASH_LOCK_TOKEN}" -H "Accept: application/json" -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance"`
        if [ -z "${STASH_PROGRESS_RESULT}" ]; then
            bail "[${STASH_URL}] ERROR: Unable to check for backup progress"
        fi
 
        STASH_PROGRESS_DB_STATE=`echo ${STASH_PROGRESS_RESULT} | jq -r '.["db-state"]'`
        STASH_PROGRESS_SCM_STATE=`echo ${STASH_PROGRESS_RESULT} | jq -r '.["scm-state"]'`
    done
 
    print "done"
    info "db state '${STASH_PROGRESS_DB_STATE}'"
    info "scm state '${STASH_PROGRESS_SCM_STATE}'"
}

function stash_backup_progress {
    STASH_REPORT_RESULT=`curl -s -f ${STASH_HTTP_AUTH} -X POST -H "Accept: application/json" -H "Content-type: application/json" "${STASH_URL}/mvc/admin/backups/progress/client?token=${STASH_LOCK_TOKEN}&percentage=$1"`
    if [ $? != 0 ]; then
        bail "Unable to update backup progress"
    fi
 
    info "Backup progress updated to $1"
}
 
function stash_unlock {
    STASH_UNLOCK_RESULT=`curl -s -f ${STASH_HTTP_AUTH} -X DELETE -H "Accept: application/json" -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance/lock?token=${STASH_LOCK_TOKEN}"`
    if [ $? != 0 ]; then
        bail "Unable to unlock instance with lock ${STASH_LOCK_TOKEN}"
    fi
 
    info "Stash instance unlocked"
}

#Locks the Instance. Do this after the initial Rsync, so we can make sure we're only catching things that were open during the first sync.
curl -s -u ${STASH_HTTP_AUTH} -X POST -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance/lock" --insecure

#Bring me the backup status
curl -s -f ${STASH_HTTP_AUTH} -X GET -H "X-Atlassian-Maintenance-Token: ${STASH_LOCK_TOKEN}" -H "Accept: application/json" -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance"


#Unlock the instance. This'll be the last thing we do. Probably.
curl -s -f ${STASH_HTTP_AUTH} -X DELETE -H "Accept: application/json" -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance/lock?token=${STASH_LOCK_TOKEN}"