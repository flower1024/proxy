#!/usr/bin/env bash

handleERR() {
    echo "$0 Error on line $1"
}
set -e
trap 'handleERR $LINENO' ERR

[[ -d /tmp/nginx/vhosts ]] && rm -rf /tmp/nginx/vhosts
[[ -d /tmp/nginx/htpasswd ]] && rm -rf /tmp/nginx/htpasswd

mkdir -p /tmp/nginx/vhosts
mkdir -p /tmp/nginx/htpasswd

[[ ! -f /etc/letsencrypt/dhparam.pem ]] && openssl dhparam -dsaparam -out /etc/letsencrypt/dhparam.pem 4096
[[ ! -d /run/nginx ]] && mkdir -p /run/nginx
[[ ! -d /tmp/nginx/tmp ]] && mkdir -p /tmp/nginx/tmp

chown spdyn:spdyn -R /tmp/nginx/tmp

cp /app/conf/nginx.conf /tmp/nginx
cp /etc/nginx/mime.types /tmp/nginx
cp /etc/nginx/fastcgi_params /tmp/nginx

nginx -c /tmp/nginx/nginx.conf &
sleep 1

[[ ! -d /tmp/letsencrypt/logs ]] && mkdir -p /tmp/letsencrypt/logs
[[ ! -d /tmp/letsencrypt/work ]] && mkdir -p /tmp/letsencrypt/work

for DOMAINDEF in $(ENV DOMAINS); do
    DOMAIN=$(ENV "$DOMAINDEF" DOMAIN)
    HTTPS=$(ENV "$DOMAINDEF" HTTPS)
    
    if [ "$HTTPS" == "certbot" ] && [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
        echo [$DOMAIN] running certbot
        certbot certonly "$CERTBOT_ARGS" --nginx --non-interactive --agree-tos --email "$CERTBOT_MAIL" -d "$DOMAIN" --nginx-server-root /tmp/nginx --logs-dir /tmp/letsencrypt/logs --work-dir /tmp/letsencrypt/work
    fi

    USERS=$(ENV "$DOMAINDEF" USERS)
    if [ "$USERS" ]; then
        echo [$DOMAIN] creating htpasswd
        for USERDEF in $USERS; do
            USER=$(ENV "$DOMAINDEF" "$USERDEF" NAME)
            PASSWORD=$(ENV "$DOMAINDEF" "$USERDEF" PASS)

            echo [$DOMAIN] - creating user "$USER"
            printf '%s:%s\n' "${USER}" "$(openssl passwd -5 "${PASSWORD}")" >> "/tmp/nginx/htpasswd/${DOMAIN}.htpasswd"
        done
    fi

    echo "[${DOMAIN}] creating vhost"
    TYPE=$(ENV "$DOMAINDEF" TYPE)
    "/app/types/nginx_config_${TYPE}.sh" "$DOMAINDEF"

done

kill "$(cat /run/nginx/nginx.pid)"
sleep 1
