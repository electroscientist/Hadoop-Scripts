#!/bin/bash

INPUT_FILE="$1";
OUTPUT_FILE="$2";
SIZEINMB="$3";

if [ $# -lt 3 ]; then
	echo "Expected 3 arguments. Got only ($#)"
	echo "Syntax: generatetextfile.sh inputfile.txt outputfile.txt sizeInMB"
fi

#if [ -z "${INPUT_FILE}" ]; then
#	echo "input file must be specified"
#	exit 1;
#fi

#if [ -z "${OUTPUT_FILE}" ]; then
#	echo "output file must be specified"
#	exit 2;
#fi

#if [ -z "${SIZEINMB}" ]; then
#	echo "output file size must be specified"
#	exit 3;
#fi

if ! [[ "${SIZEINMB}" =~ ^[0-9]+$ ]] ; then
	exec >&2; echo "error: sizeInMB must be an integer number."; 
	echo "Syntax: generatetextfile.sh inputfile.txt outputfile.txt sizeInMB"
	exit 4;
fi

#-------------------------------------------------------------------------------
# Check if file specified as input file exists.

if [[ ! -e "${INPUT_FILE}" || -d ${INPUT_FILE} ]]
then
	echo "error: input file ${INPUT_FILE} not found. Abort."
	exit 5;
fi
#-------------------------------------------------------------------------------
if [ -e ${OUTPUT_FILE} ]; then
	echo "Warning: Output file already exists!"
	
	read -n1 -p "Overwrite [Y/n]?" REPLY
	echo ""
	if [ -z ${REPLY} ]; then REPLY="y"; fi
	case "${REPLY}" in
		    y|Y     )
	;;
		    *       )       echo "Abort"
				exit 6;
	;;
	esac
fi
#-------------------------------------------------------------------------------
inputfilesize=$(ls -l "${INPUT_FILE}" | awk '{print $5}');
if ! [[ "${inputfilesize}" =~ ^[0-9]+$ ]] ; then
	exec >&2; echo "error: while determining input file size."; 
	echo "Abort"
	exit 7;
fi
#-------------------------------------------------------------------------------


outputfilesize_desired=$(echo "scale=0; ${SIZEINMB}*1024*1024" | bc);
printf "%-30s" "Desired output file size:"
printf "%15d Bytes\n" ${outputfilesize_desired}

times=$(echo "scale=0; ${outputfilesize_desired}/$inputfilesize" | bc)
if [ $times -le 0 ];
then
	echo "Input file too big to be used for creating output file."
fi

outputfilesize_target=$(echo "scale=0; ${times}*${inputfilesize}" | bc);

printf "%-30s" "Actual output file size:"
printf "%15d Bytes\n" ${outputfilesize_target}
#-------------------------------------------------------------------------------

cat ${INPUT_FILE} > ${OUTPUT_FILE}

for (( t=2; t<=$times; t++ ))
do
	cat ${INPUT_FILE} >> ${OUTPUT_FILE}

	#-----------------------------------------------------
	
	positions=50;
	filled=$(echo "scale=0; (${t}*${positions})/${times}" | bc);
	printf "["
	for ((p=1; p<=$filled; p++))
	do
		printf "%s" "="
	done
	remaining=$(echo "scale=0; ${positions}-${filled}" | bc);
	
	printf ">%${remaining}s] %3d%%" "" $(echo "scale=0; ${filled}*100/${positions}" | bc);
	
	if [[ ${remaining} -gt 0 && ${t} -lt ${times} ]]; then
		printf "\r"
	else
		printf "\n"
	fi
	#-----------------------------------------------------

	#printf "%04d/%04d\r" ${t} ${times}
done


#-------------------------------------------------------------------------------
#Sanity Check
outputfilesize_actual=$(ls -l "${OUTPUT_FILE}" | awk '{print $5}');
if [ ${outputfilesize_target} -ne ${outputfilesize_actual} ];
then
	echo "Warning: output file does not have the expected size!"
fi
echo "Done."






