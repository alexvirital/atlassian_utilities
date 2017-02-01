#!/bin/sh
# Atlassian Backups v 1.0
# Written by Alex Merenyi, Enterprise Services

# Take backups for both the /var and /opt directories of Confluence
tar -czvf /backup/confluence/conf_var_backup-$(date +%y%m%d).tar /var/atlassian/application-data/confluence/
tar -czvf /backup/confluence/conf_opt_backup-$(date +%y%m%d).tar /opt/atlassian/confluence

# Destroy backup files older than 2 days
find /backup/confluence -ctime +2 -delete
