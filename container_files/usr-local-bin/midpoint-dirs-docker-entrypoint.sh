#!/bin/sh
if [ -e /opt/midpoint-dirs-docker-entrypoint ] ; then
	echo "Processing midpoint-dirs-docker-entrypoint directory..."
	for i in $( find /opt/midpoint-dirs-docker-entrypoint -mindepth 1 -maxdepth 1 -type d ) ; do
		l_name=$(basename ${i})
		[ ! -e ${MP_DIR}/var/${l_name} ] && mkdir -p ${MP_DIR}/var/${l_name}
                for s in $( find ${i} -mindepth 1 -maxdepth 1 -type f -follow -exec basename \{\} \; ) ; do 
                        if [ ! -e ${MP_DIR}/var/${l_name}/${s} -a ! -e ${MP_DIR}/var/${l_name}/${s}.done ]
                        then
				echo "COPY ${i}/${s} => ${MP_DIR}/var/${l_name}/${s}"
                                cp ${i}/${s} ${MP_DIR}/var/${l_name}/${s}
			else
				echo "SKIP: ${i}/${s}"
                        fi
                done
        done
	echo "- - - - - - - - - - - - - - - - - - - - -"
fi

/usr/local/bin/startup.sh
