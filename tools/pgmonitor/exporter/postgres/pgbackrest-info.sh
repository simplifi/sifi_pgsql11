#!/usr/bin/env bash

[ -f /etc/pgmonitor.conf ] && . /etc/pgmonitor.conf

if [ -z "$PGBACKREST_CONFIGS" ]; then
    conf="default"
    echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --output=json info | tr -d '\n')

else

    IFS=':' read -r -a array <<< "$PGBACKREST_CONFIGS"

    for conf in "${array[@]}"
    do
        echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --config=$conf --output=json info | tr -d '\n')
    done

fi
