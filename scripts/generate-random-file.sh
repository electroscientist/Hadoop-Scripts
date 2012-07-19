#!/bin/bash


if [ $# -lt 2 ]; then
  echo "Syntax: createfile outputfile sizeinMB">&2;
  exit 1;
fi

if [ $# -gt 2 ]; then
  echo "(Too many arguments) Syntax: createfile outputfile sizeinMB">&2;
  exit 1;
fi

SCRIPT_DIR=`dirname "$0"`
SCRIPT_DIR=`cd "${SCRIPT_DIR}"; pwd`

OUTPUT_FILE=$1
SIZE_MB=$2
if ! [[ "${SIZE_MB}" =~ ^[0-9]+$ ]] ; then
	echo "error: sizeInMB must be an integer number.">&2; 
	exit 1;
fi

FILE_SIZE=$((${SIZE_MB}*1024*1024));

#echo "Creating file: ${OUTPUT_FILE}"
#echo "File size ${SIZE_MB} MB (${FILE_SIZE} bytes)"
#dd if=/dev/zero of=${OUTPUT_FILE} bs=${FILE_SIZE} count=1;
dd if=/dev/urandom of=${OUTPUT_FILE} bs=${FILE_SIZE} count=1;
exit $?


