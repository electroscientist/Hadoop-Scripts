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
if [ $# -lt 2 ]; then
  echo "Usage:   del-block.sh PATHNAME BLKNUM1 BLKNUM2 ..."
  echo "         PATHNAME is the name of a file and BLKNUMx is the number (id) of the x-th blocks to be removed."
  echo "Example: del-block.sh /path/to/file.dat 0 1 8"
  exit 1
fi

HADOOP_HOME=$(cd "${HADOOP_HOME}"; pwd);
HADOOP_CONF_DIR="${HADOOP_HOME}/conf";


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
HADOOP_TMP_DIR="${HADOOP_TMP_DIR}/dfs";

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

blockList=$(hadoop org.apache.hadoop.hdfs.tools.DFSck $pathName -files -blocks -locations 2>&1 1>&1| grep -e "blk_-*[0-9]*");
#echo "$blockList"

numOfBlocks=$( echo "$blockList" | wc -l);
#echo $numOfBlocks

#check blocks
for arg in $*; do
	if ! [[ "$arg" =~ ^[0-9]+$ ]] || [[ "$arg" -lt 0 ]] || [[ "$arg" -ge "$numOfBlocks" ]]; then
		echo "error: invalid arg $arg -- BLKNUM must be a number in [0 - $(($numOfBlocks-1))]" >&2
		exit 1;
	fi
done


# Iterate over the block-ids to be removed
stat_arg_del=0;
stat_arg_failed=0;
stat_arg_missing=0;
stat_arg_total=0;

while (( "$#" )); do
	
	let stat_arg_total+=1;

	blkToDelNum="$1";
	#echo $blkToDelNum

	if [ $blkToDelNum -gt 0 ]; then
		# strip zeros at the begging of the blkToDelNum
		blkToDelNum="$(echo $blkToDelNum | sed 's/^0*//')"
	elif [ $blkToDelNum -eq 0 ]; then
		blkToDelNum="0";
	fi
	#echo $blkToDelNum

	blkToDelEntry=$( echo "$blockList" | grep "^$blkToDelNum. blk_");
	#echo $blkToDelEntry
	if [ -z "${blkToDelEntry}" ]; then
		echo "error: no block with number ${blkToDelNum} exists."
		echo "warn : skipping argument $blkToDelNum";
		let stat_arg_failed+=1;
		shift;
		continue;
	fi

	blkIsMissing=$(echo "$blkToDelEntry" | grep "MISSING" | wc -l);
	if [ $blkIsMissing -gt 0 ]; then
		echo "warn: blk $blkToDelNum already missing.";
		echo "warn : skipping argument $blkToDelNum";
		let stat_arg_missing+=1;
		shift;
		continue;
	fi

	blkToDelName=$(echo "$blkToDelEntry" | awk '{ print $2 }' | cut -d'_' -f 1,2);
	#echo $blkToDelName
	blkToDelRemoteLocs=$(echo "$blkToDelEntry" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}');
	#echo $blkToDelRemoteLocs

	numOfBlkLocations=$(echo $blkToDelRemoteLocs | wc -w);

	if [ ${numOfBlkLocations} -gt 1 ];
	then
		echo "warn: Block found in more than one location: ${blkToDelRemoteLocs}"
	fi

	replicas_deleted=0;
	for ip in ${blkToDelRemoteLocs};
	do

		if [ -z ${ip} ];
		then
			echo "warn: error deleting block ${blkToDelName} - Host ip is empty.">&2;
			continue;
		fi


		if [ "$ip" == "127.0.0.1" ]; then

			ATTEMPTS=3;
			while [ $ATTEMPTS -gt 0 ]; do
				let ATTEMPTS-=1;
			
				#echo "info: block ${blkToDelName} stored in localhost."
				cmd="find ${HADOOP_TMP_DIR} -name ${blkToDelName}"
				#echo $cmd
				blkLocalPath=$(eval $cmd) # keep only the first path matching
				if [ -n "$blkLocalPath" ]; then
					# printf "%-70s\n" "info: removing block ${blkToDelName} and meta from  ${ip} ..."
					cmd="rm ${blkLocalPath} ${blkLocalPath}_*.meta"
					#echo $cmd
					eval $cmd
					if [ $? -eq 0 ]; then 
						let replicas_deleted+=1;
					else 
						echo -n "warn: error deleting block ${blkToDelName} from ${ip}.">&2;
						if [ $ATTEMPTS -gt 0 ]; then
							echo "Retrying..">&2;
							continue;
						else
							echo "Quit.">&2;
						fi
					fi
				fi
			done;

		else
	
			ATTEMPTS=3;
			while [ $ATTEMPTS -gt 0 ]; do
				let ATTEMPTS-=1;
			
				#echo "info: block ${blkToDelName} stored in remote host $ip. (Assuming that hadoop.tmp.dir is ${HADOOP_TMP_DIR})"
				cmd="ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 ${ip} 'find ${HADOOP_TMP_DIR} -name ${blkToDelName}'"
				#echo $cmd
				blkLocalPath=$(eval $cmd | awk 'NR==1')  # keep only the first path matching
				if [ -n "$blkLocalPath" ]; then
					#printf "%-70s\n" "info: removing block ${blkToDelName} and meta from  ${ip} ..."
					cmd="ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 ${ip} 'rm ${blkLocalPath} ${blkLocalPath}_*.meta'"
					#echo $cmd
					eval $cmd
					if [ $? -eq 0 ]; then 
						let replicas_deleted+=1;
					else 
						echo -n "warn: error deleting block ${blkToDelName} from ${ip}.">&2;
						if [ $ATTEMPTS -gt 0 ]; then
							echo "Retrying..">&2;
							continue;
						else
							echo "Quit.">&2;
						fi
					fi
				fi
			done;
		fi
	
	done
	if [ ${replicas_deleted} -eq ${numOfBlkLocations} ]; then
		let stat_arg_del+=1;
	else
		let stat_arg_failed+=1;
	fi
shift;

done

echo "Blocks deleted $stat_arg_del (total=$stat_arg_total, deleted=$stat_arg_del, failed=$stat_arg_failed, missing=$stat_arg_missing)";

if [ $stat_arg_failed -gt 0 ]; then
	exit 2;
fi
exit 0;


