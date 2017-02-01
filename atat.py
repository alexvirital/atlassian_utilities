#!/bin/py
# Atlassian Total Automation tool (ATAT)
# Written by Alex Merenyi for The Advisory Board Company
# Script title has nothing at all to do with the Imperial Walkers of the same name. (...or does it.)
# Version 0.1 started March 25, 2014


# Matches version 3.8 of the CLI package. Updates to that package WILL require updates below. 

###
#Imports. Don't modify. 
import os
import sys
import subprocess
import getpass
import ldap
import ldap.modlist as modlist
###

#####
# Important objects. These should be changed depending on what server, account, or the location of the CLI client.

# This is the user we use for everything. It needs to be a domain user, with rights to create and modify groups. It must also already exist in all Atlassian applications.
autouser = ( "DN OF QUAL'D USER" )

# This should be a file path. Don't hardcode the password, duh.
autopass = ( "passwordgoeshereyo" ) #/path/to/pswdfile)
temppass = getpass.getpass('Password:')


# The Location in your directory where you want to drop your groups. 
baseDN = ( "DC=COMPANY,DC=com" )

# Your Primary Domain Controller (PDC)
primaryDC = ( "ldaps://domaincontroller.domain.com:636/" )

# We need to know where the .jar for the CLI package is. Update for specific versions (Or symlink to versions. I'm not your boss.)
jirajarloc = ( "jira-cli/lib/jira-cli.3.8.0.jar" )
stshjarloc = ( "stash-cli/lib/stash-cli.3.8.0.jar" )
confjarloc = ( "confleunce-cli/lib/confluence-cli.3.8.0.jar" )

# Also, let's set the locations of our various servers while we're at it.
jirainstance = ( "http://jira:8080" )
stshinstance = ( "http://stash:8080" )
confinstance = ( "http://confluence:8080" )

#with those set, we now have the prepending ability to access the CLI pacakges remotely.
call_jira = 'java -jar `%s --server %s --user %s --password %s`' % (jirajarloc,jirainstance,autouser,autopass)
call_stsh = 'java -jar `%s --server %s --user %s --password %s`' % (stshjarloc,stshinstance,autouser,autopass)
call_conf = 'java -jar `%s --server %s --user %s --password %s`' % (confjarloc,confinstance,autouser,autopass)

num_existing_adgroups = 0

# Python LDAP Stuff. Define the scope of the search, return all attributes, and filter your search results.
ldap_searchScope = ldap.SCOPE_SUBTREE
ldap_retrieveAttributes = ["sAMAccountName"]

# Actual user input stuff.
while True:
	dept = raw_input("Enter Department: ")
	proj_name = raw_input("Enter Desired Project name: ")
	spkey = raw_input("Enter Desired key: ").lower()
	print("Project is named %s-%s, project key is %s. OK? N to repeat, any other key to continue."%(dept,proj_name,spkey))
	n = raw_input()
	if n != "N":
		break

#
#End of Variables. Beware of modifying below this line. 
#######

# First, we open the connection to Active Directory. 
print("Contacting Domain, please wait.")
try:
	l = ldap.initialize(primaryDC)
	l.simple_bind_s(autouser, temppass)
	print("Domain contact successful, bind OK.")
	#Any error here will log as an exception, and be printed by the below.
except ldap.LDAPError, e:
	print e

ldap_searchFilter = "cn=*%s*"%(spkey)

try:
	print("Searching for prexisting %s groups in Active Directory."%(spkey))
	ldap_result_id = l.search(baseDN, ldap_searchScope, ldap_searchFilter, ldap_retrieveAttributes)
	result_set = []
	while 1:
		result_type, result_data = l.result(ldap_result_id, 0)
		if (result_data == []):
			break
		else:
			## here you don't have to append to a list
			## you could do whatever you want with the individual entry
			## The appending to list is just for illustration. 
			if result_type == ldap.RES_SEARCH_ENTRY:
				result_set.append(result_data)
				num_existing_adgroups = num_existing_adgroups+1
	#Any error here will log as an exception, and be printed by the below.
except ldap.LDAPError, e:
	print e

if num_existing_adgroups == 0:
	print("Found no groups corresponding to key %s"%(spkey))
else:
	print("Found %d groups"%(num_existing_adgroups))
	print("The following groups were found already associated with that key:")
	print result_set
ldap_group_present_response = raw_input("OK to proceed? Y to continue, anything else to quit.")
if (ldap_group_present_response != "Y"):
	print("Quitting based on user input.")
	sys.exit(0)
else:
	print("Continuing with group creation.")

#Close the AD Connection. This should be performed after all AD functions are complete.
l.unbind_s()
