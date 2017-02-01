#!/bin/sh
# maintainence mode deactivation script for apache applications
# January 21st 2014

# must be run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please re-run either as root or via sudo. Quitting . . . " 
   exit 1
fi

echo "Running as root."
echo "Swapping httpd.conf to default mode."

rm /etc/httpd/conf/httpd.conf
cp /etc/httpd/conf/httpd.default.conf /etc/httpd/conf/httpd.conf

echo "Swapping ssl.conf to default mode."

rm /etc/httpd/conf.d/ssl.conf
cp /etc/httpd/conf.d/ssl.default.conf /etc/httpd/conf.d/ssl.conf

echo "Restarting httpd."

service httpd restart

echo "Done."