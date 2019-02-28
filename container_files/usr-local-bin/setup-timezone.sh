#!/bin/bash

if [[ -n $TIMEZONE ]]; then
    echo "*** Setting timezone to '$TIMEZONE'"
    if [[ -e /usr/share/zoneinfo/$TIMEZONE ]]; then
        unlink /etc/localtime
        ln -s /usr/share/zoneinfo/$TIMEZONE /etc/localtime
        echo "date (UTC) is: $(date -u)"
        echo "date (current timezone) is $(date)"
    else
        echo "Error: time zone '$TIMEZONE' is unknown; not setting it."
    fi
fi
