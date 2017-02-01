#!/bin/sh
# Stash/Bitbucket Rebuild Script v 0.1
# Coepit XIX April MMXIV, et spiritum machinae laudabitur

# I'll refer to stash in here despite the official rebrand to Bitbucket. Something something old man easily confused

### Definitions
# These may change depending on the previous state of Stash/Bitbucket. Verify these quarterly. (If the script is failing, the problem could well be here.)

MOUNT="/stash"
VERSION="3.11.4"
APPUSER="stash"

# Check this regularly; this should be the DIRECT PATH to the S/BB installer on Atlassian's servers. 
INSTALLER=""


### DATABASE

# Database config... this will be input by the end-user and written to the config file which controls stash DB access. Assuming MSSQL; will break (hard) if it's not.
DB_NAME=""
DB_SERVER=""
DB_USER=""
DB_PASSWORD=""
DB_PORT=""

DBLOOP=true
endloop=""

# First, determine if the stash home directory has been mounted yet. If not, break out; there's nothing we can do yet.

if [ -d $MOUNT ]; then
echo "Found Stash/Bitbucket data directory at $MOUNT. Continuing . . . ";
else
echo "Stash/Bitbucket data directory not found: $MOUNT not found. Exiting . . . ";
break
fi

# Next, determine if the stash user exists. If not, create them.

if grep -q $APPUSER /etc/passwd ; then
	echo "found Stash user, $APPUSER";
else
	echo "No Stash user found. Creating.";
	echo "addusr $APPUSER";
fi

# We don't know where the DB is going to be restored to, so let's prompt the user to fill that data in. 

while [ $DBLOOP == true ]; do
	echo "Enter DB server:"
	read DB_SERVER
	echo "Enter DB port:"
	read DB_PORT
	echo "Enter DB Name:"
	read DB_NAME
	echo "Enter DBUser:"
	read DB_USER
	echo "Enter DB User Password:"
	read DB_PASSWORD
	echo "DB Info as follows: Server $DB_SERVER : $DB_PORT, Name of $DB_NAME"
	echo "DB login info: $DB_USER / $DB_PASSWORD . "
	echo "Y to continue, any other key to CLEAR entry and try again."
	read endloop
	if [ $endloop == "Y" ] || [ $endloop == "y" ]; then
		DBLOOP = false
	fi
done

# Now that we have that data, we need to print it. There's a good chance that the stash-config.properties file already exists, so we don't want to overwrite it; after the
# disaster is over, we want to be able to revert our changes. So we're writing to a secndary file, then copying it into place after the old file has been moved out.

if [ -f $MOUNT/home/shared/stash-config.recovery ]; then
	echo "Found stash-config.recovery file, presuming it's from a previous attempt at running this script. If this is incorrect BREAK IMMEDIATELY and remove it, then rerun script."
	echo "Press Enter to continue, or Ctrl-C to break now."
	read old_reco_pause
else
	echo "Writing Configuration file for Stash now. Assuming MSSQL and provided variables. If not MSSQL, things are about to get weird."
	/usr/bin/touch $MOUNT/home/shared/stash-config.recovery
	echo "jdbc.url=jdbc:sqlserver://$DB_SERVER:$DB_PORT;instanceName=Internal;databaseName=$DB_NAME;" >> $MOUNT/home/shared/stash-config.recovery
	echo "jdbc.user=$DB_USER" >> $MOUNT/home/shared/stash-config.recovery
	echo "jdbc.password=$DB_PASSWORD" >> $MOUNT/home/shared/stash-config.recovery
	echo "jdbc.driver=com.microsoft.sqlserver.jdbc.SQLServerDriver"  >> $MOUNT/home/shared/stash-config.recovery
	echo "plugin.stash-branch-information.timeout=30" >> $MOUNT/home/shared/stash-config.recovery
	echo "jmx.enabled=true" >> $MOUNT/home/shared/stash-config.recovery
		if [ -f $MOUNT/home/shared/stash-config.properties ]; then
		echo "Previous stash-config.properties file exists. Assuming this was prior to disaster; renaming to .old and setting aside."
		/usr/bin/cp $MOUNT/home/shared/stash-config.properties $MOUNT/home/shared/stash-config.old
	fi
fi

# Quick bit of error checking to make sure everything's copacetic.

if [ -f $MOUNT/home/shared/stash-config.recovery ]; then
	echo "Recovery file ready for placement. Placing."
	/usr/bin/cp $MOUNT/home/shared/stash-config.recovery $MOUNT/home/shared/stash-config.properties
else
	echo "Recovery file not found. Please rerun script. Exiting . . . "
	break
fi

### END DATABASE

### SUPPORTING PROCESSES

# Okay, now we need to get four major systems working before Stash can come up: wget, git, httpd, and java.
## WGET 


if which wget; then
	echo "wget found."
else
	echo "wget not found. Installing..."
	/usr/bin/yum install wget -y
fi


## GIT
# git time. The version of git in yum is woefully outdated and Stash will not use it. Whomp whomp.

if which git; then
	echo "git found."
else
	echo "git not found. Installing..."
	yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel gcc perl-ExtUtils
	wget -O /opt/ https://www.kernel.org/pub/software/scm/git/git-2.4.9.tar.gz
	tar -xzvf /opt/git-2.4.9.tar.gz
	/usr/bin/make -C /opt/git-2.4.9/ prefix=/usr/local/git all
	/usr/bin/make -C /opt/git-2.4.9/ prefix=/usr/local/git install
	echo "export PATH=$PATH:/usr/local/git/bin" >> /etc/bashrc

	# Ok, that's all well and good. Let's go ahead and make sure things actually, you know, worked.
	if git --version; then
		echo "git install successful. Moving on."
	else
		echo "git install failed. Please install manually then restart script. Quitting . . . "
		break
	fi
fi


## HTTPD
# Okay, now it's time for Apache. This is almost secondary; SSH operations will run if Apache's down. Still, it's a good idea and reasonably quick to set up.

if [ -f /etc/init.d/httpd ]; then
	echo "Apache detected."
else
	echo "Apache not found. Installing."
	yum install -y httpd mod_ssl
fi

# The httpd configs (including the ssl cert/key, etc) can't be rebuilt out of thin air the way everything else can. So let's recover those to the directories we need.

mv /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.orig
cp $MOUNT/recovery/httpd.conf /etc/httpd/conf/httpd.conf

mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.orig
cp $MOUNT/recovery/ssl.conf /etc/httpd/conf.d/ssl.conf

# Assumption: if the TLS directory exists, certs and keys probably exists (as either someone helpfully created them, or this isn't our first run through of this script.)

if [ -d /etc/pki/tls ]; then
	echo "TLS directory OK"
else
	mkdir /etc/pki/tls
	mkdir /etc/pki/tls/certs
	mkdir /etc/pki/tls/keys
fi

# We're going to make a couple assumptions - 1, that we're maintaining the folder structure for certficates. 2, that certs and keys will maintain a consistent naming scheme.
# Probably not a safe assumption to make, but if it changes, update here. 

cp $MOUNT/recovery/*.cer /etc/pki/tls/certs
cp $MOUNT/recovery/*.crt /etc/pki/tls/certs
cp $MOUNT/recovery/*.key /etc/pki/tls/keys

if find stash* /etc/pki/tls/certs; then
	echo "Stash certificate OK"
else
	echo "No Stash cert found. Please re-run script."
fi

if find stash* /etc/pki/tls/keys; then
	echo "Stash key OK"
else
	echo "No Stash private key found. Please re-run script."
fi

service httpd start


## JAVA
# Currently in production we have alternatives set up to manage JAVA. This is great and how we should do things long-term, but for now we have an outage and need to get running.

if java -version; then
	echo "Java found and installed. Moving on.";
else
	echo "Java not present. Installing."
	mkdir /usr/java
	/usr/bin/wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u77-b03/jdk-8u77-linux-x64.tar.gz" -O /usr/java/jdk-8u77-linux-x64.tar.gz
	tar -xzvf /usr/java/jdk-8u77-linux-x64.tar.gz
	ln -s /usr/java/jdk-1.8_77/jre/bin/java /usr/bin/java
	









