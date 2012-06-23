#!/usr/bin/env bash

# Script used to manually delete a block of a file stored in dfs from the local
# filesystem of the datanode. It serves HDFS-RAID testing purposes;
# a block removed from the system should be spotted by hadoop and repaired.
# The script should be run at the master node (namenode).
# It partially supports deleting files in remote hosts (using ssh),
# assuming that the directory under which blocks are stored is the one
# determined by the hadoop.tmp.dir property in core-site.xml file in the master
# node.

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

# if no args specified, show usage
if [ $# = 0 ]; then
  echo "Usage: del-block PATHNAME BLKNUM"
  echo "       PATHNAME is the name of a file and BLKNUM is the number of the block to be removed."
  exit 1
fi

HADOOP_HOME=$(cd "${HADOOP_HOME}"; pwd);
HADOOP_CONF_DIR="${HADOOP_HOME}/conf";

#cygwin=false
#case "`uname`" in
#CYGWIN*) cygwin=true;;
#esac

# Attempt to determine the directory under which hadoop stores blocks in the 
# local file system, througth the hadoop.tmp.dir property of core-site.xml file.
HADOOP_TMP_DIR="";
if ! [ -d "${HADOOP_CONF_DIR}" ] || ! [ -e "${HADOOP_CONF_DIR}/core-site.xml" ]; then
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
	echo "warn: assuming hadoop.tmp.dir is /app/hadoop"
	HADOOP_TMP_DIR="/app/hadoop";
fi

pathName="$1"
shift

hadoop dfs -test -e $pathName
pathExists=$?
if [ $pathExists -ne 0  ]; then
 echo "error: PATHNAME $pathName does not exist."
 exit 1
fi

hadoop dfs -test -d $pathName
pathIsDir=$?
if [ $pathIsDir -eq 0  ]; then
 echo "error: PATHNAME is a directory."
 exit 1
fi
#echo $pathName

numOfBlocks=$(hadoop org.apache.hadoop.hdfs.tools.DFSck $pathName -files -blocks -locations 2>&1 1>&1| grep -e "blk_-*[0-9]*" | wc -l);
#echo $numOfBlocks

blkToDelNum=""
if [ $# -gt 0 ]; then
	blkToDelNum="$1";
fi
#echo $blkToDelNum

if [ -z "$blkToDelNum" ]; then
	echo "warn: No blk specified. Deleting blk 0."
	blkToDelNum=0
fi
#echo $blkToDelNum

if ! [[ "$blkToDelNum" =~ ^[0-9]+$ ]] ; then
	echo "error: BLKNUM must be a number in [0 - $(($numOfBlocks-1))]" >&2
	exit 1
fi

if [ $blkToDelNum -gt 0 ]; then
	# strip zeros at the begging of the blkToDelNum
	blkToDelNum="$(echo $blkToDelNum | sed 's/^0//')"
fi
#echo $blkToDelNum

blkToDelEntry=$(hadoop org.apache.hadoop.hdfs.tools.DFSck $pathName -files -blocks -locations 2>&1 1>&1| grep "$blkToDelNum. blk_");
#echo $blkToDelEntry
if [ -z "${blkToDelEntry}" ]; then
	echo "error: no block with number ${blkToDelNum} exists."
	exit 1;
fi

blkIsMissing=$(echo "$blkToDelEntry" | grep "MISSING" | wc -l);
if [ $blkIsMissing -gt 0 ]; then
	echo "warn: blk $blkToDelNum already missing.";
	exit 0;
fi

blkToDelName=$(echo "$blkToDelEntry" | awk '{ print $2 }' | cut -d'_' -f 1,2);
#echo $blkToDelName
blkToDelRemoteLocs=$(echo "$blkToDelEntry" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}');
#echo $blkToDelRemoteLocs


if [ $(echo $blkToDelRemoteLocs | wc -w) -gt 1 ];
then
	echo "warn: Block found in more than one location: ${blkToDelRemoteLocs}"
	continue;
fi

for ip in ${blkToDelRemoteLocs};
do

	if [ -z ${ip} ];
	then
		echo "(** Host ip is empty. Skip block.)"
		continue;
	fi


	if [ "$ip" == "127.0.0.1" ]; then
		echo "info: block ${blkToDelName} stored in localhost."
		cmd="find ${HADOOP_TMP_DIR} -name ${blkToDelName}*"
		#echo $cmd
		blkLocalPath=$(eval $cmd)
		printf "%-70s\n" "info: removing block ${blkToDelName} and meta from  ${ip} ..."
		cmd="rm ${blkLocalPath}"
		#echo $cmd
		eval $cmd
	else
		echo "info: block ${blkToDelName} stored in remote host $ip. (Assuming that hadoop.tmp.dir is ${HADOOP_TMP_DIR})"
		cmd="ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 ${ip} 'find ${HADOOP_TMP_DIR} -name ${blkToDelName}*'"
		#echo $cmd
		blkLocalPath=$(eval $cmd)
		printf "%-70s\n" "info: removing block ${blkToDelName} and meta from  ${ip} ..."
		cmd="ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 ${ip} 'rm ${blkLocalPath}'"
		#echo $cmd
		eval $cmd
		if [ $? -eq 0 ]; then echo "OK"; else echo "FAIL"; fi
	fi
	
done

exit 0


