#!/bin/sh
# atlassian build script

mkdir /opt/atlassian
yum -y install httpd
yum -y install mod_ssl

wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u92-b14/jdk-8u92-linux-x64.tar.gz
tar -xzvf jdk-8u92-linux-x64.tar.gz -C /opt/
mv /opt/jdk1.8.0_92/jre/lib/security/cacerts /opt/jdk1.8.0_92/jre/lib/security/cacerts_orig
alternatives --install /usr/bin/java java /opt/jdk1.8.0_92/bin/java 2 

echo "1 for stash, 2 for jira, 3 for confluence"
read app

if [ $app == "1" ]
	then
		echo "downloading stash"
		wget https://www.atlassian.com/software/stash/downloads/binary/atlassian-stash-3.11.4.tar.gz
		tar -xzvf atlassian-stash-3.11.4.tar.gz -C /opt/atlassian/
		ln -s atlassian-stash-3.11.4/ /opt/atlassian/stash
		adduser stash
		chown -Rv stash:stash /opt/atlassian/atlassian-stash-3.11.4/
		scp amerenyi@stash:/opt/jre1.8.0_66/lib/security/cacerts /opt/jdk1.8.0_92/jre/lib/security/cacerts

fi

if [ $app == "2" ]
	then
		echo "downloading jira"
		wget https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-7.1.4-jira-7.1.4.tar.gz
		tar -xzvf atlassian-jira-software-7.1.4-jira-7.1.4.tar.gz -C /opt/atlassian/
		ln -s atlassian-jira-software-7.1.4/ /opt/atlassian/jira
		adduser jira
		chown -Rv jira:jira /opt/atlassian/atlassian-jira-software-7.1.4/
		scp amerenyi@jira:/opt/jdk1.8.0_77/jre/lib/security/cacerts /opt/jdk1.8.0_92/jre/lib/security/cacerts
fi

if [ $app == "3" ]
	then
		echo "downloading confluence"
		wget https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-5.10.2.tar.gz
		tar -xzvf atlassian-confluence-5.10.2.tar.gz -C /opt/atlassian/
		ln -s atlassian-confluence-5.10.2/ /opt/atlassian/confluence
		adduser confluence
		chown -Rv confluence:confluence /opt/atlassian/atlassian-confluence-5.10.2/
		scp amerenyi@wiki:/opt/jdk1.8.0_92/jre/lib/security/cacerts /opt/jdk1.8.0_92/jre/lib/security/cacerts
fi