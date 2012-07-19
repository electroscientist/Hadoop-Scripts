#!/usr/bin/env bash

export rs_HADOOP_USER=hduser;
# The file to be created in dfs for testing.
export rs_DFS_FILE_PATH=/user/hduser/bob.dat

# The directory RAID uses for parity files.
export rs_PARITY_FILE_DIR=/raidsrc

# A local file to be copied to dfs.
# If this variable is left empty, a random file of size rs_FILE_SIZE will be
# generated.
export rs_LOCAL_FILE=/app/hadoop/data/bob640.dat

# File size in MB. Size is used only if rs_LOCAL_FILE is left blank.
export rs_FILE_SIZE=640;

# Blocks to be deleted from the original file for testing.
export rs_BLOCK_SETS_FILE="0 1
1 2
4 5
8 9
0 5 9";

# Blocks to be deleted from the parity file for testing.
export rs_BLOCK_SETS_PARITY="0 1
0 2
3 4 5";


export rs_TEMP_DIR=/tmp/hadoop-tests

export rs_SEC_TO_WAIT_FOR_RAID=500;
export rs_SEC_TO_WAIT_FOR_REPAIR=300;


