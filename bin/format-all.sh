#!/usr/bin/env bash

# Script to perform a heavy format of hadoop filesystem 
# (usefull for developing purposes).
# -Delete the directories of the local filesystem where blocks are stored.
# -Format the hadoop fileystem.
# -Archive log files and clean log directory.

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`


daemonsRunning=$(jps | egrep -i 'namenode|datanode|tasktracker|jobtracker|raidnode' | wc -l);
if [ ${daemonsRunning} -gt 0 ]; then
	echo "warn: services running (run jps). Stop all before formatting."
	exit 1;
fi

HADOOP_HOME=$(cd "${HADOOP_HOME}"; pwd);
#echo "${HADOOP_HOME}"

if ! [ "$bin" == "${HADOOP_HOME}/bin" ]; then
	echo "error: must place and run script in ${HADOOP_HOME}/bin"
	exit 1;
fi

#echo ${bin}
. "${HADOOP_HOME}"/bin/hadoop-config.sh

# Attempt to determine the directory under which hadoop stores blocks in the 
# local file system, througth the hadoop.tmp.dir property of core-site.xml file.
HADOOP_TMP_DIR="";
if [ -z "${HADOOP_CONF_DIR}" ] || ! [ -d "${HADOOP_CONF_DIR}" ] || ! [ -e "${HADOOP_CONF_DIR}/core-site.xml" ]; then
	echo "warn: unspecified conf dir; will not know hadoop.tmp.dir";
else
	# check if  xmlstarlet tool is available
	which xmlstarlet > /dev/null
	if [ $? -ne 0 ];
	then
		echo "warn: xmlstarlet tool not availabe; cannot read xml conf file."
		echo "warn: Consider downloading:"
		echo "warn: sudo apt-get -y --allow-unauthenticated --force-yes install xmlstarlet"
	else
		HADOOP_TMP_DIR=$(xmlstarlet sel -t -v "/configuration/property[name='hadoop.tmp.dir']/value" ${HADOOP_CONF_DIR}/core-site.xml);
		#echo "${HADOOP_TMP_DIR}"
	fi
fi

# If we have not been able to specify hadoop.tmp.dir
if [ -z "${HADOOP_TMP_DIR}" ]; then
	echo "warn: could not determine hadoop.tmp.dir; local fs not cleaned."
else
	rm -rf "${HADOOP_TMP_DIR}"/*
fi


HADOOP_LOG_DIR="${HADOOP_HOME}/logs"
#echo ${HADOOP_LOG_DIR}



if ! [ -d "${HADOOP_LOG_DIR}" ]; then
	echo "warn: could not determing hadoop log dir; skipping archiving."
else
	
	CURDATETIME=`date +%m%d%y_%H%M%S`;
	ARCHIVE=logs-${CURDATETIME}.tar.gz

	echo "info: compressing log dir ${HADOOP_LOG_DIR}";

	# Create archive -------------------
	echo "${HADOOP_LOG_DIR}/.."
	tar -czf "${HADOOP_LOG_DIR}/../${ARCHIVE}" ${HADOOP_LOG_DIR} 
	#-----------------------------------				
	
	echo "info: cleaning log dir ${HADOOP_LOG_DIR}";
	rm -rf "${HADOOP_LOG_DIR}"/*
fi


echo "info: formatting hadoop file system:"
${HADOOP_HOME}/bin/hadoop namenode -format


