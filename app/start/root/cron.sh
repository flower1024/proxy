#!/usr/bin/env bash

handleERR() {
    echo "$0 Error on line $1"
}
set -e
trap 'handleERR $LINENO' ERR

chown spdyn:spdyn /tmp

exec busybox crond -f -L /dev/stdout