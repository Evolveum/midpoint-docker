#!/bin/bash

/usr/local/bin/log-timezone.sh

if [ $(grep -c "container" ${MP_DIR}/bin/midpoint.sh) -eq 0 ]; then \
	${MP_DIR}/bin/midpoint.sh
else
	/usr/local/bin/start-midpoint.sh
fi
