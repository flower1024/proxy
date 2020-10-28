FROM flower1024/ghost-python3

ARG UID=82
ARG GID=82

COPY /app /app/

RUN apt-get install -y -q curl dnsutils nginx python3-certbot-nginx openssl && \
    chmod ugo+x -R /app/init && \
    chmod ugo+x -R /app/scripts && \
    chmod ugo+x -R /app/start && \
    chmod ugo+x -R /app/types && \
    USER spdyn ${UID} spdyn ${GID} && \
    echo "* * * * * /app/scripts/update.sh" > /var/spool/cron/crontabs/spdyn && \
    touch /tmp/error.log && \
    if [ -f /var/log/nginx/error.log ]; then rm /var/log/nginx/error.log; fi && \
    ln -s /tmp/error.log /var/log/nginx/error.log && \
    echo "0 1 * * * /app/scripts/cerbot_renew.sh" > /var/spool/cron/crontabs/root

EXPOSE 80 443

HEALTHCHECK --interval=60s --timeout=15s CMD curl http://localhost/ping | grep -qm1 pong

VOLUME [ "/etc/letsencrypt" ]
