#!/usr/bin/env bash

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

if [ $# -ne 2 ]; then
	echo "Usage: clone-from-dfs-to-local.sh /dfs/path/to/file /local/dir";
	exit 2;
fi

DFS_PATH=$1;
shift;
LOCAL_ROOT_DIR="${1%/}";
shift;

DFS_PATH_NAME=$(basename "$DFS_PATH");
DFS_PATH_DIR=$(dirname "$DFS_PATH");

LOCAL_CLONE_DIR=${LOCAL_ROOT_DIR}/${DFS_PATH_DIR#/};

if [[ ! -d ${LOCAL_CLONE_DIR} ]]; then
	mkdir -p ${LOCAL_CLONE_DIR};
	if [ $? -ne 0 ]; then exit 1; fi
fi

${HADOOP_HOME}/bin/hadoop dfs -get "${DFS_PATH}" "${LOCAL_CLONE_DIR}"
exit $?
