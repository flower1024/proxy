#!/usr/bin/env bash

handleERR() {
    echo "$0 Error on line $1"
}
set -e
trap 'handleERR $LINENO' ERR

[[ ! -f /tmp/IPv4 ]] && echo "" > /tmp/IPv4
[[ ! -f /tmp/IPv6 ]] && echo "" > /tmp/IPv6

MYIP4=$(cat /tmp/IPv4)
NEWIP4=$(dig @ns1-1.akamaitech.net ANY whoami.akamai.net +short)

if [ "$MYIP4" = "$NEWIP4" ]
then
    exit
fi

if [ ! -d /tmp/netrc ]
then
    mkdir -p /tmp/netrc

    for HOST in $(ENV HOSTS)
    do
        USER=$(ENV HOSTS "$HOST" USER)
        PASS=$(ENV HOSTS "$HOST" PASS)
        DOMAIN=$(ENV HOSTS "$HOST" DOMAIN)

        cat <<EOT > "/tmp/netrc/IPv4_${DOMAIN}.netrc"
machine update.spdyn.de
login $USER
password $PASS
EOT
    done
fi

for HOST in $(ENV HOSTS)
do
    USER=$(ENV HOSTS "$HOST" USER)
    PASS=$(ENV HOSTS "$HOST" PASS)
    DOMAIN=$(ENV HOSTS "$HOST" DOMAIN)

    curl --netrc-file "/tmp/netrc/IPv4_${DOMAIN}.netrc" -s "https://update.spdyn.de/nic/update?hostname=${DOMAIN}&myip=${NEWIP4}" | sed -e "s/^/[UPDATE] ${DOMAIN} to ${NEWIP4}: /" -e 's/$/\n/'
done

echo "$NEWIP4" > /tmp/IPv4