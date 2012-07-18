#!/usr/bin/env bash

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. $bin/crash-test-BLOCK_SETS.sh

if [ -z "$ct_FILENAME" ]; then
	echo "error: filename not specied in argument file" >&2;
	exit 1;
else
	FILENAME="$ct_FILENAME";
fi

if [ -z "$ct_BLOCK_SETS" ]; then
	echo "error: sets to delete not specied in argument file" >&2;
	exit 1;
else
	BLOCK_SETS="$ct_BLOCK_SETS";
fi


export ct_SEC_TO_WAIT_FOR_REPAIR=300;


NUM_OF_BLOCK_SETS=$(echo "$BLOCK_SETS" | wc -l);

RAID_RESCAN_INTERVAL=$(xmlstarlet sel -t -v "/configuration/property[name='raid.policy.rescan.interval']/value" ${HADOOP_HOME}/conf/hdfs-site.xml);

for i in $(seq 1 $NUM_OF_BLOCK_SETS);
do
	
	BLOCK_SET=$(echo "$BLOCK_SETS" | awk "NR==$i");
	#echo $BLOCK_SET

	echo "Deleting blocks: $BLOCK_SET"
	${HADOOP_HOME}/del-block.sh $FILENAME $BLOCK_SET

	#===========================================================================	
	echo -n "Wait for raid to detect corrupt file.."
	ATTEMPTS=10
	SECS_PER_ATTEMPT=$((2*$RAID_RESCAN_INTERVAL/$ATTEMPTS/1000));
	while [ $ATTEMPTS -gt 0 ]; do
		let ATTEMPTS-=1
	
		fsck_output=$(hadoop fsck $FILENAME 2>/dev/null);
		isCorrupt=$(echo "$fsck_output" | grep -c "CORRUPT");
		isHealthy=$(echo "$fsck_output" | grep -c "HEALTHY");
		
		if [[ $isCorrupt -eq 0 && $isHealthy -gt 0 ]]; then
			echo -n "."
			sleep $SECS_PER_ATTEMPT;
			continue;
		elif [[ $isCorrupt -gt 0 && $isHealthy -eq 0 ]]; then
			echo " detected."
			break;
		else
			echo "unhandled situation (1): debug: $fsck_output"
			exit 1;
		fi
	done
	if [[ $ATTEMPTS -eq 0 && $isCorrupt -eq 0 && $isHealthy -gt 0 ]]; then 
		echo "time out"
		exit 1;
	elif [ $ATTEMPTS -eq 0 ]; then
		echo "unhandled situation (2): debug: $fsck_output"
	fi

	#===========================================================================
	echo -n "Waiting for repair.."
	
	ATTEMPTS=10
	SECS_PER_ATTEMPT=$(($ct_SEC_TO_WAIT_FOR_REPAIR/$ATTEMPTS));
	while [ $ATTEMPTS -gt 0 ]; do
		let ATTEMPTS-=1
	
		fsck_output=$(hadoop fsck $FILENAME 2>/dev/null);
		isCorrupt=$(echo "$fsck_output" | grep -c "CORRUPT");
		isHealthy=$(echo "$fsck_output" | grep -c "HEALTHY");
		
		if [[ $isCorrupt -gt 0 && $isHealthy -eq 0 ]]; then
			echo -n "."
			sleep $SECS_PER_ATTEMPT;
			continue;
		elif [[ $isCorrupt -eq 0 && $isHealthy -gt 0 ]]; then
			echo " repaired."
			break;
		else
			echo "unhandled situation: debug: $fsck_output"
			exit 1;
		fi
	done
	if [[ $ATTEMPTS -eq 0 && $isCorrupt -gt 0 && $isHealthy -eq 0 ]]; then 
		echo "time out"
		exit 1;
	elif [ $ATTEMPTS -eq 0 ]; then
		echo "unhandled situation (3): debug: $fsck_output"
	fi

done

