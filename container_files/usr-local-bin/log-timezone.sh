#!/bin/bash

if [[ -n $TZ ]]; then
    echo "*** Used timezone: '$TZ'"
    if [[ -e /usr/share/zoneinfo/$TZ ]]; then
        echo "date (UTC) is: $(date -u)"
        echo "date (current timezone) is $(date)"
    else
        echo "Error: time zone '$TIMEZONE' is unknown"
    fi
fi
