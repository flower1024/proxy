#!/usr/bin/env bash

handleERR() {
    echo "$0 Error on line $1"
}
set -e
trap 'handleERR $LINENO' ERR

DOMAINDEF=$1

getEnvValue() {
    local var="${DOMAINDEF}_${1}"
    if [ "$2" ]; then
        var="${var}_${2}"
    fi
    echo "${!var}"
}

DOMAIN=$(getEnvValue DOMAIN)

cat <<EOT > "/tmp/nginx/vhosts/${DOMAIN}.conf"
server {
	server_name                             ${DOMAIN};
	listen 									80;
    resolver                                127.0.0.11;

	location /.well-known/acme-challenge/ {
		auth_basic                          off;
		allow                               all;
		root                                /var/lib/letsencrypt/;
		try_files                           \$uri =404;
		break;
	}

EOT

HTTP=$(getEnvValue HTTP)
if [ "$HTTP" == "redirect-https" ]; then

cat <<EOT >> "/tmp/nginx/vhosts/${DOMAIN}.conf"
	location / {
		return                              301 https://\$host\$request_uri;
	}
}
EOT

else

    if [ -f "/tmp/nginx/htpasswd/${DOMAIN}.htpasswd" ]; then

cat <<EOT >> "/tmp/nginx/vhosts/${DOMAIN}.conf"
    auth_basic                              $(getEnvValue AUTHNAME);
    auth_basic_user_file                    /tmp/nginx/htpasswd/${DOMAIN}.htpasswd;
EOT

    fi

    SERVER=$(getEnvValue SERVER)
    if [ "$SERVER" ]; then
        for SERVERCONF in $SERVER; do
            CONF=$(getEnvValue SERVER "$SERVERCONF")
            echo -e '\t'"$CONF" >> "/tmp/nginx/vhosts/${DOMAIN}.conf"
        done

    fi

    LOCATION=$(getEnvValue LOCATION)
    if [ "$LOCATION" ]; then
cat <<EOT >> "/tmp/nginx/vhosts/${DOMAIN}.conf"
	location $LOCATION {
        set                                 \$upstreamloc $(getEnvValue LOCATIONUPSTREAM);
		proxy_pass                          http://\$upstreamloc;
    }
EOT
    fi

cat <<EOT >> "/tmp/nginx/vhosts/${DOMAIN}.conf"
	location / {
        set                                 \$upstream $(getEnvValue UPSTREAM);
		proxy_pass                          http://\$upstream;
    }
}
EOT

fi

HTTPS=$(getEnvValue HTTPS)

if [ "$HTTPS" ]; then

cat <<EOT >> "/tmp/nginx/vhosts/${DOMAIN}.conf"

server {
	server_name                             ${DOMAIN};
	client_max_body_size 10G;
	listen                                  443 ssl http2;
	
    resolver                                127.0.0.11;
    include                                 /etc/letsencrypt/options-ssl-nginx.conf;
	ssl_certificate                         /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
	ssl_certificate_key                     /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
	ssl_dhparam                             /etc/letsencrypt/dhparam.pem;
	ssl_stapling                            on;
	ssl_stapling_verify                     on;
	ssl_trusted_certificate                 /etc/letsencrypt/live/${DOMAIN}/chain.pem;
	add_header Strict-Transport-Security    "max-age=31536000" always;

EOT

if [ -f "/tmp/nginx/htpasswd/${DOMAIN}.htpasswd" ]; then

cat <<EOT >> "/tmp/nginx/vhosts/${DOMAIN}.conf"
    auth_basic                              $(getEnvValue AUTHNAME);
    auth_basic_user_file                    /tmp/nginx/htpasswd/${DOMAIN}.htpasswd;
EOT

fi

SERVER=$(getEnvValue SERVER)
if [ "$SERVER" ]; then
    for SERVERCONF in $SERVER; do
        CONF=$(getEnvValue SERVER "$SERVERCONF")
        echo -e '\t'"$CONF" >> "/tmp/nginx/vhosts/${DOMAIN}.conf"
    done

fi

LOCATION=$(getEnvValue LOCATION)
if [ "$LOCATION" ]; then
cat <<EOT >> "/tmp/nginx/vhosts/${DOMAIN}.conf"
location $LOCATION {
set                                 \$upstreamloc $(getEnvValue LOCATIONUPSTREAM);
	proxy_pass                          http://\$upstreamloc;
}

EOT
fi


cat <<EOT >> "/tmp/nginx/vhosts/${DOMAIN}.conf"

	location / {
        set                                 \$upstream $(getEnvValue UPSTREAM);
		proxy_pass                          http://\$upstream;
    }
}

EOT

fi
