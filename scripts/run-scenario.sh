#!/usr/bin/env bash

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

if [ $# -ne 1 ]; then
	echo "Usage: run-scenario.sh SCENARIOFILE";
	echo "SCENARIOFILE is a file initializing variables required by this script.";
	echo "Use senario-template.sh as an example";
	exit 2;
fi

SCENARIO_FILE="$1";

if [[ ! -e "$SCENARIO_FILE" ]]; then
	echo "error: SCENARIOFILE $SCENARIO_FILE not found";
	exit 1;
fi

# Load scenario variables
. $SCENARIO_FILE

if [[ -z $rs_DFS_FILE_PATH || -z $rs_TEMP_DIR || -z $rs_FILE_SIZE ]]; then
	echo "error: file did not initilize crucial variables."
	echo "abort";
	exit 1;
fi

#===============================================================================

DFS_FILE_PATH="$rs_DFS_FILE_PATH";
FILE_NAME=$(basename "$DFS_FILE_PATH");


echo "DFS path: $DFS_FILE_PATH"

# Check if the dfs path already exists.
${HADOOP_HOME}/bin/hadoop dfs -test -e "${DFS_FILE_PATH}"
if [ $? -eq 0 ]; then
	echo "error: dfs path $DFS_FILE_PATH already exists. Abort.">&2;
	exit 1;
fi
#===============================================================================

echo -n "Creating local temporary directories..."

CURDATETIME=$(date +%m%d%y_%H%M%S);
LOCAL_TMP_ROOT_DIR="$rs_TEMP_DIR";
LOCAL_TMP_SCENARIO_DIR="$LOCAL_TMP_ROOT_DIR/$CURDATETIME";

# Initialize temporary storage
if [ ! -d "${LOCAL_TMP_ROOT_DIR}" ]; then
	
	mkdir -p ${LOCAL_TMP_ROOT_DIR};
	if [ $? -ne 0 ]; then
		echo ""
		echo "error: could not initialize temp dir ($rs_TEMP_DIR). Abort">&2;
		exit 1;
	fi
fi

DIR_BEFORE="$LOCAL_TMP_SCENARIO_DIR/before";
DIR_AFTER="$LOCAL_TMP_SCENARIO_DIR/after";
mkdir -p "$DIR_BEFORE";
mkdir -p "$DIR_AFTER";

echo "done";
#===============================================================================

# Determine the "original" file to be placed into dfs.
ORIGINAL_FILE="$LOCAL_TMP_ROOT_DIR/$CURDATETIME/$FILE_NAME";

if [ -z $rs_LOCAL_FILE ]; then
	# No local file specified. 
	# Generate a random file.
	echo "File to use: (not specified)";
	FILE_SIZE=$rs_FILE_SIZE;
	echo "File size: $FILE_SIZE MBs";
	echo "Generating file..."
	${bin}/generate-random-file.sh $ORIGINAL_FILE $FILE_SIZE
	if [ $? -ne 0 ]; then
		echo ""
		echo "error: generating file. Abort">&2;
		exit 1;
	fi

else
	# Use an existing file as "original" file.
	echo "File to use: $rs_LOCAL_FILE";
	if [[ ! -e "$rs_LOCAL_FILE" ]]; then
		echo "error: specified file does not exist. Abort">&2;
		exit 1;
	else
		echo "File size: $(ls -la /app/hadoop/data/$rs_LOCAL_FILE | cut -d' ' -f5) bytes"
	fi
	cp $rs_LOCAL_FILE $ORIGINAL_FILE
fi
#===============================================================================

echo -n "Copying file into DFS... "
${HADOOP_HOME}/bin/hadoop dfs -put "$ORIGINAL_FILE" "$DFS_FILE_PATH"
if [ $? -ne 0 ]; then
	echo ""
	echo "error: copying file into DFS. Abort">&2;
	exit 1;
else
	echo "done";
fi

echo -n "Removing ${ORIGINAL_FILE}... "
rm "${ORIGINAL_FILE}";
echo "done"

#===============================================================================
echo -n "Wait for file to be raided.."
# Wait for all blocks to get replication equal to 1.
CHECK_INTERVAL=5;
while true; do
	res=$(${bin}/check-if-raided.sh $DFS_FILE_PATH);
	if [ $? -ne 0 ]; then echo "error: checking if file is raided."; fi

	if [ "$res" == "no" ]; then
		echo -n "."
		sleep $CHECK_INTERVAL;
		continue;
	elif [ "$res" == "yes" ]; then
		echo " done"
		break;
	else
		echo " "
		echo "unhandled situation: debug : res=$res">&2
		exit 1;
	fi
done

#-------------------------------------------------------------------------------


DFS_PARITY_PATH="${rs_PARITY_FILE_DIR%/}/${DFS_FILE_PATH#/}";
while true; do
	echo "Looking for parity file: $DFS_PARITY_PATH"
	${HADOOP_HOME}/bin/hadoop dfs -test -e "${DFS_PARITY_PATH}"
	if [ $? -ne 0 ]; then
		echo "error: could not find parity file for $DFS_PARITY_PATH";
		read -p "Parity File: "
		DFS_PARITY_PATH="$REPLY";
		DFS_PARITY_NAME=$(basename "$DFS_PARITY_PATH");
		DFS_PARITY_DIR=$(dirname "$DFS_FIPARITYLE_PATH");
	else
		break;
	fi
done;

echo -n "Retrieving main file from dfs to local temp dirs..."
ATTEMPTS=5;
while [ $ATTEMPTS -gt 0 ]; do
	let ATTEMPTS-=1;
	${bin}/clone-from-dfs-to-local.sh ${DFS_FILE_PATH} ${DIR_BEFORE}
	clone=$?;

	if [[ $clone -ne 0 && $ATTEMPTS -eq 0 ]]; then
		echo "error: could not copy path $DFS_FILE_PATH to local fs">&2;
		rm -rf ${DIR_BEFORE}/${DFS_FILE_PATH}/*
	elif [ $clone -ne 0 ]; then
		echo -n "."
		sleep 10;
		continue;	
	else
		break;
	fi
done;
echo " done"

echo -n "Retrieving parity file from dfs to local temp dirs..."
ATTEMPTS=5;
while [ $ATTEMPTS -gt 0 ]; do
	let ATTEMPTS-=1;
	${bin}/clone-from-dfs-to-local.sh ${DFS_PARITY_PATH} ${DIR_BEFORE}
	clone=$?;

	if [[ $clone -ne 0 && $ATTEMPTS -eq 0 ]]; then
		echo "error: could not copy path $DFS_PARITY_PATH to local fs">&2;
		rm -rf ${DIR_BEFORE}/${DFS_PARITY_PATH}/*
	elif [ $clone -ne 0 ]; then
		echo -n "."
		sleep 10;
		continue;	
	else
		break;
	fi
done;
echo " done"

${bin}/crash-test.sh --report=$LOCAL_TMP_SCENARIO_DIR/main-file-hdfs-bytes-read.txt ${DFS_FILE_PATH} "${rs_BLOCK_SETS_FILE}"
res=$?;
if [ $res -ne 0 ]; then
	echo "error: could not complete crash test on main file">&2;
fi
${bin}/crash-test.sh --report=$LOCAL_TMP_SCENARIO_DIR/parity-file-hdfs-bytes-read.txt ${DFS_PARITY_PATH} "${rs_BLOCK_SETS_PARITY}"
res=$?;
if [ $res -ne 0 ]; then
	echo "error: could not complete crash test on parity file">&2;
fi

echo -n "Retrieving main file from dfs to local temp dirs..."
ATTEMPTS=5;
while [ $ATTEMPTS -gt 0 ]; do
	let ATTEMPTS-=1;
	${bin}/clone-from-dfs-to-local.sh ${DFS_FILE_PATH} ${DIR_AFTER}
	clone=$?;

	if [[ $clone -ne 0 && $ATTEMPTS -eq 0 ]]; then
		echo "error: could not copy path $DFS_FILE_PATH to local fs">&2;
		rm -rf ${DIR_AFTER}/${DFS_FILE_PATH}/*
	elif [ $clone -ne 0 ]; then
		echo -n "."
		sleep 10;
		continue;	
	else
		break;
	fi
done;
echo " done"
echo -n "Retrieving parity file from dfs to local temp dirs..."
ATTEMPTS=5;
while [ $ATTEMPTS -gt 0 ]; do
	let ATTEMPTS-=1;
	${bin}/clone-from-dfs-to-local.sh ${DFS_PARITY_PATH} ${DIR_AFTER}
	clone=$?;

	if [[ $clone -ne 0 && $ATTEMPTS -eq 0 ]]; then
		echo "error: could not copy path $DFS_PARITY_PATH to local fs">&2;
		rm -rf ${DIR_AFTER}/${DFS_PARITY_PATH}/*
	elif [ $clone -ne 0 ]; then
		echo -n "."
		sleep 10;
		continue;	
	else
		break;
	fi
done;
echo " done"

echo -n "Comparing original and retrieved files..."
DIFFS=$(diff -r --brief ${DIR_BEFORE} ${DIR_AFTER});
if [ $? -ne 0 ]; then
	echo ""
	echo "error: executing diff.">&2
fi
if [ -z "${DIFFS}" ]; then
	echo "Matching!"
else
	echo "Differences detected.";
	echo "$DIFFS"
fi



