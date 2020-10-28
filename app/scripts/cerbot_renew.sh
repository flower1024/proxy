#!/usr/bin/env bash

handleERR() {
    echo "$0 Error on line $1"
}
set -e
trap 'handleERR $LINENO' ERR

certbot renew "$CERTBOT_ARGS" -q --non-interactive --nginx-server-root /home/nginx --logs-dir /tmp/letsencrypt/logs --work-dir /tmp/letsencrypt/work

nginx -s reload
