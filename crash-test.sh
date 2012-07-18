#!/usr/bin/env bash

FILENAME=/user/hduser/bob.dat
SEC_TO_WAIT_FOR_REPAIR=300

. ${HADOOP_HOME}/crash-test-sets.sh
NUM_OF_SETS=$(echo "$SETS" | wc -l);

RAID_RESCAN_INTERVAL=$(xmlstarlet sel -t -v "/configuration/property[name='raid.policy.rescan.interval']/value" ${HADOOP_HOME}/conf/hdfs-site.xml);

for i in $(seq 1 $NUM_OF_SETS);
do
	
	BLOCK_SET=$(echo "$SETS" | awk "NR==$i");
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
	SECS_PER_ATTEMPT=$(($SEC_TO_WAIT_FOR_REPAIR/$ATTEMPTS));
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

