#!/usr/bin/env bash
#
# Author: misi (Mishi)
# Twitter: @misi
# Website: https://roadtoaws.com/
#
# License: Apache-2.0 License
#
# This script sets up Let's Encrypt SSL certificates and automatic renewal
# on AWS Lightsail instances using lego: https://github.com/go-acme/lego
#
# Usage: sudo ./lightsail-ssl.sh [domain] [email]
# [domain] and [email] arguments are optional
# if they are not provided the script will ask for them
#
# Options:
#   -h, --help
#                Print help message
#   -v, --version
#                Print version number
#

version="1.1.1"
date_format="%Y/%m/%d %T"

# Message function
message () {
  echo "$(date +"${date_format}") [${1}] ${2}"
}

# Cleanup function
cleanup () {
  message "INFO" "Removing temporary files"
  rm --force /tmp/"${file}"
}

# Simple help
if [[ ("${1}" = "--help") || ("${1}" = "-h") ]]
then
  echo "This script will setup Let's Encrypt SSL on your AWS Lightsail instance" 
  echo "Usage: ${0} [domain] [email]"
  exit 0
fi

# Simple version
if [[ ("${1}" = "--version") || ("${1}" = "-v") ]]
then
  echo "${0}"
  echo "Version: ${version}"
  exit 0
fi

# Check if the script is executed as root
if [[ "${EUID}" -ne 0 ]]
then
  message "ERROR" "This script must be run as root!"
  exit 1
fi

# Check if domain argument exists, if not ask for it
message "NOTICE" "Let's Encrypt will validate your domain before issuing an SSL certificate"
if [ -n "${1}" ]
then
  message "INFO" "Using domain name from the argument: ${1}"
  domain=${1}
else
  echo "What is your domain name? [example.com]"
  read -r domain < /dev/tty
fi

# Set the proper hostname for the instance
message "INFO" "Setting your domain name as the hostname"
hostnamectl set-hostname "${domain}"

# Check if email argument exists, if not ask for it
message "NOTICE" "Let's Encrypt will send notifications to your Email address when the SSL certificate is expiring"
if [ -n "${2}" ]
then
  message "INFO" "Using Email address from the argument: ${2}"
  email=${2}
else
  echo "What is your Email address? [email@email.com]"
  read -r email < /dev/tty
fi

# Update package list
message "INFO" "Executing package list update"
apt-get update

# Update packages
message "INFO" "Executing package update"
apt-get --assume-yes upgrade

# Install Lego
message "INFO" "Installing Lego (Let's Encrypt client and ACME library) client"
url=$(curl --location --silent https://api.github.com/repos/xenolf/lego/releases/latest | grep browser_download_url | grep linux_amd64 | cut --delimiter '"' -f 4)
file="${url##*/}"
curl --location --silent https://api.github.com/repos/xenolf/lego/releases/latest | grep browser_download_url | grep linux_amd64 | cut --delimiter '"' -f 4 | wget --directory-prefix=/tmp --input-file=-
tar --extract --directory /tmp --file=/tmp/"${file}"
mkdir --parents /opt/bitnami/letsencrypt
mv --force /tmp/lego /opt/bitnami/letsencrypt/lego
mv --force /tmp/CHANGELOG.md /opt/bitnami/letsencrypt/CHANGELOG.md
mv --force /tmp/LICENSE /opt/bitnami/letsencrypt/LICENSE

# We need to stop Bitnami in order to install the certificate
message "INFO" "Stopping Bitnami services (temporarily)"
/opt/bitnami/ctlscript.sh stop

# Request the certificate
message "INFO" "Requesting new Let's Encrypt Certificate"
/opt/bitnami/letsencrypt/lego --accept-tos --tls --email="${email}" --domains="${domain}" --domains="www.${domain}" --path="/opt/bitnami/letsencrypt" run

# Check if the certificate request was successfull
# if not we don't touch anything
if [ ! -f /opt/bitnami/letsencrypt/certificates/"${domain}".key ]
then
  message "INFO" "Starting Bitnami services"
  /opt/bitnami/ctlscript.sh start
  cleanup
  message "ERROR" "Missing new certificate"
  message "INFO" "Check if your DNS is set up correctly and rerun this script"
  echo "Done"
  exit 1
fi

# Replace the certificate
message "INFO" "Configuring webserver with the new certificate"
if [ -f /opt/bitnami/apache/conf/bitnami/certs/server.crt ]
then
  crt_location="/opt/bitnami/apache/conf/bitnami/certs/"
elif [ -f /opt/bitnami/apache2/conf/server.crt ]
then
  crt_location="/opt/bitnami/apache2/conf/"
else
  message "INFO" "Starting Bitnami services"
  /opt/bitnami/ctlscript.sh start
  cleanup
  message "ERROR" "Old Apache certificate could not be located"
  echo "Done"
  exit 2
fi
mv "${crt_location}"server.crt "${crt_location}"server.crt.old
mv "${crt_location}"server.key "${crt_location}"server.key.old
ln --symbolic --force /opt/bitnami/letsencrypt/certificates/"${domain}".key "${crt_location}"server.key
ln --symbolic --force /opt/bitnami/letsencrypt/certificates/"${domain}".crt "${crt_location}"server.crt
chown root:root /opt/bitnami/apache2/conf/server*
chmod 600 /opt/bitnami/apache2/conf/server*

# Start up Bitnami
message "INFO" "Starting Bitnami services"
/opt/bitnami/ctlscript.sh start

# Create a script for automatic renewal
message "INFO" "Setting up Automatic Let's Encrypt renewal"
mkdir --parents /opt/bitnami/letsencrypt/scripts
echo "#!/usr/bin/env bash
sudo /opt/bitnami/ctlscript.sh stop apache
sudo /opt/bitnami/letsencrypt/lego --tls --email=${email} --domains=${domain} --path='/opt/bitnami/letsencrypt' renew --days 90
sudo /opt/bitnami/ctlscript.sh start apache" > /opt/bitnami/letsencrypt/scripts/renew-certificate.sh
chmod +x /opt/bitnami/letsencrypt/scripts/renew-certificate.sh

# Update crontab to run the new renewal script
message "INFO" "Updating crontab"
if [[ "$(crontab -l)" = "no crontab for bitnami" ]]
then
  echo "0 0 1 * * /opt/bitnami/letsencrypt/scripts/renew-certificate.sh 2> /dev/null" | crontab -
else
  (crontab -l && echo "0 0 1 * * /opt/bitnami/letsencrypt/scripts/renew-certificate.sh 2> /dev/null") | crontab -
fi

cleanup

# Display WordPress credentials
message "INFO" "Displaying your WordPress credentials"
cat /home/bitnami/bitnami_credentials

echo "Done"

exit 0
