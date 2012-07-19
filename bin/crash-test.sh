#!/usr/bin/env bash

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

if [ $# -gt 0 ]; then
	# OVERWRITE THE FILE SETTING
	FILENAME="$1";
	shift;
	BLOCK_SETS="$1";
	shift;
fi

BLOCK_SETS=$(echo "$BLOCK_SETS" | grep -E '^(\s*[0-9]+\s*)(,\s*[0-9]+\s*)*(\|\s*[0-9]+\s*(,\s*[0-9]+\s*))*$');
if [ $? -ne 0 ]; then
	echo "error: second argument must be a list of block-sets."
fi

BLOCK_SETS=$(echo "$BLOCK_SETS" | perl -p -e 's/\s//g');
BLOCK_SETS=$(echo "$BLOCK_SETS" | perl -p -e 's/\|/\n/g;s/,/ /g');
NUM_OF_BLOCK_SETS=$(echo "$BLOCK_SETS" | wc -l);

for i in $(seq 1 $NUM_OF_BLOCK_SETS);
do
	
	BLOCK_SET=$(echo "$BLOCK_SETS" | awk "NR==$i");
	#echo $BLOCK_SET

	echo "Deleting blocks: $BLOCK_SET"
	${bin}/del-block.sh $FILENAME $BLOCK_SET
	if [ $? -ne 0 ]; then 
		echo "error: deleting blocks. Abort">&2; 
		exit 1;	
	fi

	#===========================================================================	
	echo -n "Wait for raid to detect corrupt file.."
	CHECK_INTERVAL=10;
	while true; do
		fsck_output=$(hadoop fsck $FILENAME 2>/dev/null);
		isCorrupt=$(echo "$fsck_output" | grep -c "CORRUPT");
		isHealthy=$(echo "$fsck_output" | grep -c "HEALTHY");
		
		if [[ $isCorrupt -eq 0 && $isHealthy -gt 0 ]]; then
			echo -n "."
			sleep $CHECK_INTERVAL;
			continue;
		elif [[ $isCorrupt -gt 0 && $isHealthy -eq 0 ]]; then
			echo " detected."
			break;
		else
			echo "unhandled situation (1): debug: $fsck_output"
			exit 1;
		fi
	done

	#===========================================================================
	echo -n "Waiting for repair.."
	CHECK_INTERVAL=10;
	while true; do
	
		fsck_output=$(hadoop fsck $FILENAME 2>/dev/null);
		isCorrupt=$(echo "$fsck_output" | grep -c "CORRUPT");
		isHealthy=$(echo "$fsck_output" | grep -c "HEALTHY");
		
		if [[ $isCorrupt -gt 0 && $isHealthy -eq 0 ]]; then
			echo -n "."
			sleep $CHECK_INTERVAL;
			continue;
		elif [[ $isCorrupt -eq 0 && $isHealthy -gt 0 ]]; then
			echo " repaired."
			break;
		else
			echo "unhandled situation: debug: $fsck_output"
			exit 1;
		fi
	done

done

