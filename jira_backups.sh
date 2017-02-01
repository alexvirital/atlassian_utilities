#!/bin/sh
# Atlassian Backups v 1.1
# Written by Alex Merenyi, Enterprise Services

# Take backups for the /opt/ directory of JIRA. This includes all attachments and configuration settings not in the database.
tar -czvf /backup/jira/conf_opt_backup-$(date +%y%m%d).tar /opt/atlassian/jira

# Destroy backup files older than 2 days
find /backup/jira -ctime +2 -delete