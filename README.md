# proxy
nginx reverse proxy with certbot and nextcloud fpm support

# docker-compose
```
    proxy:
        image: flower1024/proxy
        restart: unless-stopped
        read_only: true
        environment: 
            - HOSTS=DOMAIN1 DOMAIN2
            - HOSTS_DEFAULT_USER=spdyn username
            - HOSTS_DEFAULT_PASS=spdyn password
            - HOSTS_DOMAIN1_DOMAIN=host.domain.tld
            - HOSTS_DOMAIN2_DOMAIN=host.domain.tld
            - CERTBOT_MAIL=mail
            - CERTBOT_ARGS=
            - DOMAINS=DOMAIN1 DOMAIN2
            - DOMAIN1_DOMAIN=host.domain.tld
            - DOMAIN1_USERS=USER1
            - DOMAIN1_USER1_NAME=username
            - DOMAIN1_USER1_PASS=password
            - DOMAIN1_TYPE=proxy
            - DOMAIN1_UPSTREAM=container:port
            - DOMAIN1_HTTPS=certbot
            - DOMAIN1_HTTP=redirect-https
            - DOMAIN1_AUTHNAME=name
            - DOMAIN1_SERVER=PROXYREDIRECT
            - DOMAIN1_SERVER_PROXYREDIRECT=proxy_redirect http://domain.onion/ /;
            - DOMAIN2_DOMAIN=host.domain.tld
            - DOMAIN2_TYPE=nextcloud
            - DOMAIN2_UPSTREAM=container:fpm-port
            - DOMAIN2_HTTPS=certbot
            - DOMAIN2_HTTP=redirect-https
            - DOMAIN2_WWWROOT=/var/www/html
        tmpfs:
            - /run
        volumes: 
            - /srv/volumes/proxy/certs:/etc/letsencrypt
            - /srv/volumes/nextcloud/app:/var/www/html:ro
            - /srv/volumes/proxy/proxy:/tmp
        ports:
            - 80:80
            - 443:443
```
