#!/bin/sh

STASH_HTTP_AUTH="-u stash_backup:[redacted]"
STASH_URL="https://staging-stash/"

STASH_LOCK=$(curl -s $STASH_HTTP_AUTH -X POST -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance/lock")
echo $STASH_LOCK

STASH_LOCK_TOKEN=`echo $STASH_LOCK | cut -d \" -f4`
echo $STASH_LOCK_TOKEN
SLACK_NOTIFY_STRING="Locked for nightly backup with lock code ${STASH_LOCK_TOKEN} ."
STARTLOCK=$(date +%s)
SLACK_NOTIFY_LOCK=$(curl -X POST -H 'Content-type: application/json' --data '{"text": "Stash: '"${SLACK_NOTIFY_STRING}"'"}' https://hooks.slack.com/services/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)
echo "Slack has been notified"
echo $SLACK_NOTIFY_LOCK

STASH_STATUS=$(curl -s -f ${STASH_HTTP_AUTH} -X GET -H "X-Atlassian-Maintenance-Token: ${STASH_LOCK_TOKEN}" -H "Accept: application/json" -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance")
echo $STASH_STATUS

while [ $STASH_STATUS != "{\"db-state\":\"AVAILABLE\",\"scm-state\":\"AVAILABLE\"}" ]
	do
	echo "Waiting for DB and SCM queue to drain. Currently $STASH_STATUS"
	wait 10
done
echo "DB and SCM queue drained, backup now"

STASH_UNLOCK_RESULT=$(curl -s -f ${STASH_HTTP_AUTH} -X DELETE -H "Accept: application/json" -H "Content-type: application/json" "${STASH_URL}/mvc/maintenance/lock?token=${STASH_LOCK_TOKEN}")
echo $STASH_UNLOCK_RESULT
ENDLOCK=$(date +%s)
DURATION="Completed in $((ENDLOCK - $STARTLOCK))s."
echo $DURATION
SLACK_NOTIFY_UNLOCK=$(curl -X POST -H 'Content-type: application/json' --data '{"text": "Backup complete. Stash lock has been lifted and Stash is ready for use. Stash backup '"$DURATION"' "}' https://hooks.slack.com/services/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)
