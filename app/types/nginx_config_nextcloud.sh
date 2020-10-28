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
	listen 					80;

    access_log                              /dev/stdout nc;
    resolver                                127.0.0.11;

	location /.well-known/acme-challenge/ {
		auth_basic                          off;
		allow                               all;
		root                                /var/lib/letsencrypt/;
		try_files                           \$uri =404;
		break;
	}

	location / {
		return                              301 https://\$host\$request_uri;
	}
}

upstream php-handler {
    server $(getEnvValue UPSTREAM);
}

server {
	server_name                             ${DOMAIN};
	listen                                  443 ssl http2;

    access_log                              /dev/stdout nc;
    resolver                                127.0.0.11;

    include                                 /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_certificate                         /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key                     /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_dhparam                             /etc/letsencrypt/dhparam.pem;
    ssl_stapling                            on;
    ssl_stapling_verify                     on;
    ssl_trusted_certificate                 /etc/letsencrypt/live/${DOMAIN}/chain.pem;
    add_header Strict-Transport-Security    "max-age=31536000" always;

    sendfile                                on;
    proxy_buffering                         off;
    proxy_max_temp_file_size                0;
    proxy_buffers                           16 16k;
    fastcgi_buffering                       off;
    fastcgi_buffers                         64 4K;

    keepalive_timeout                       65;

    set_real_ip_from                        10.0.0.0/8;
    set_real_ip_from                        172.16.0.0/12;
    set_real_ip_from                        192.168.0.0/16;
    real_ip_header                          X-Real-IP;

    add_header Referrer-Policy "no-referrer" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Download-Options "noopen" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header X-Robots-Tag "none" always;
    add_header X-XSS-Protection "1; mode=block" always;

    fastcgi_hide_header X-Powered-By;

    root $(getEnvValue WWWROOT);

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location = /.well-known/carddav {
        return 301 \$scheme://\$host:\$server_port/remote.php/dav;
    }

    location = /.well-known/caldav {
        return 301 \$scheme://\$host:\$server_port/remote.php/dav;
    }

        client_max_body_size 10G;

    # Enable gzip but do not remove ETag headers
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;

    location / {
        rewrite ^ /index.php;
    }

    location ~ ^\/(?:build|tests|config|lib|3rdparty|templates|data)\/ {
        deny all;
    }
    location ~ ^\/(?:\.|autotest|occ|issue|indie|db_|console) {
        deny all;
    }

    location ~ ^\/(?:index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+)\.php(?:$|\/) {
        fastcgi_split_path_info ^(.+?\.php)(\/.*|)$;
        set \$path_info \$fastcgi_path_info;
        try_files \$fastcgi_script_name =404;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$path_info;
        # fastcgi_param HTTPS on;

        # Avoid sending the security headers twice
        fastcgi_param modHeadersAvailable true;

        # Enable pretty urls
        fastcgi_param front_controller_active true;
        fastcgi_pass php-handler;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
    }

    location ~ ^\/(?:updater|oc[ms]-provider)(?:$|\/) {
        try_files \$uri/ =404;
        index index.php;
    }

    # Adding the cache control header for js, css and map files
    # Make sure it is BELOW the PHP block
    location ~ \.(?:css|js|woff2?|svg|gif|map)$ {
        try_files \$uri /index.php\$request_uri;
        add_header Cache-Control "public, max-age=15778463";
        # Add headers to serve security related headers (It is intended to
        # have those duplicated to the ones above)
        # Before enabling Strict-Transport-Security headers please read into
        # this topic first.
        #add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;" always;
        #
        # WARNING: Only add the preload option once you read about
        # the consequences in https://hstspreload.org/. This option
        # will add the domain to a hardcoded list that is shipped
        # in all major browsers and getting removed from this list
        # could take several months.
        add_header Referrer-Policy "no-referrer" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Download-Options "noopen" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Permitted-Cross-Domain-Policies "none" always;
        add_header X-Robots-Tag "none" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Optional: Don't log access to assets
        access_log off;
    }

    location ~ \.(?:png|html|ttf|ico|jpg|jpeg|bcmap|mp4|webm)$ {
        try_files \$uri /index.php\$request_uri;
        # Optional: Don't log access to other assets
        access_log off;
    }

}

EOT
