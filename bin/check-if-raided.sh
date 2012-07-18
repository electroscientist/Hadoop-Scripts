#!/usr/bin/env bash

# Check if a file has been raided.
# In this version, check is carried out by looking at the replication factor of
# the systematic blocks (blocks of the file):
# - if replication level is 1 for all blocks, then the file is considered 
#   raided.
#
# Exit code:
# 0 : all blocks have replication factor equal to 1 - file has been raided.
# 1 : file does not exist
# 2 : invalid number of arguments
#

if [ $# -ne 1 ]; then
	echo "Usage: check-if-raided /dfs/path/to/file"
	exit 2;
fi

FILENAME=$1;

# Check if file exists
${HADOOP_HOME}/bin/hadoop dfs -test -e $FILENAME
if [ $? -ne 0 ]; then
	echo "file not found" >&2
	exit 1;
fi

# Count the number of blocks with replication factor greater than 1.
COUNT="${HADOOP_HOME}/bin/hadoop fsck $FILENAME -files -blocks -locations 2>/dev/null | grep blk_ | cut -d' ' -f4 | cut -d'=' -f2 | grep -c 1 --invert"

NUM_OF_REPLICATED_BLOCKS=$(eval $COUNT)

if [ $NUM_OF_REPLICATED_BLOCKS -gt 0 ]; then
	echo "no"
else
	echo "yes"
fi

exit 0;

