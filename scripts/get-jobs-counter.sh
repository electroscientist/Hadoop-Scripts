#!/usr/bin/env bash

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`


FROM_VALUE="";
TO_VALUE="";
CTR_NAME="";

optspec=":h-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -) 
            case "${OPTARG}" in
                from)
                    FROM_VALUE="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    #echo "Parsing option: '--${OPTARG}', value: '${FROM_VALUE}'" >&2;
                    ;;
                from=*)
                    FROM_VALUE=${OPTARG#*=}
                    opt=${OPTARG%=$FROM_VALUE}
                    #echo "Parsing option: '--${opt}', value: '${FROM_VALUE}'" >&2
                    ;;
                to)
                    TO_VALUE="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    #echo "Parsing option: '--${OPTARG}', value: '${TO_VALUE}'" >&2;
                    ;;
                to=*)
                    TO_VALUE=${OPTARG#*=}
                    opt=${OPTARG%=$TO_VALUE}
                    #echo "Parsing option: '--${opt}', value: '${TO_VALUE}'" >&2
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;
            esac;;
        h)
			echo "Prints a list of jobID and the corresponding value of the counter" >&2
			echo "given as a parameter. The value is the Total value (sum of " >&2
			echo "value for Map and Reduce phases." >&2
			echo "" >&2
            echo "usage:   $0 [--from[=]<YYYYMMDDhhmmss>] [--to[=]<YYYYMMDDhhmmss>] COUNTERNAME" >&2
			echo "         COUNTERNAME is the name of the counter as it appears in the job tracker's web interface." >&2
			echo "Example: $0 HDFS_BYTES_READ" >&2
			echo "         $0 --from=20120719112452 HDFS_BYTES_READ" >&2
			echo "         $0 \"Total time spent by all maps\"" >&2
            exit 2
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
            ;;
    esac
done
shift $(($OPTIND - 1))

CTR_NAME="$1";

if [ -z "$CTR_NAME" ]; then
	echo "error: no counter name provided" >&2
	exit 2;
fi


JOB_LIST=$(${HADOOP_HOME}/bin/hadoop job -list all | grep -e "job_[0-9]*_[0-9]*" |  awk -F"\t" '{ print $1"\t"strftime("%Y%m%d%H%M%S",$3/1000); }' );
#echo "$JOB_LIST"

# FILTER OUT jobs that started before --from value
if [ -n "$FROM_VALUE" ]; then
	JOB_LIST=$(echo "$JOB_LIST" | awk -v fv=$FROM_VALUE -F"\t" '$2 >= fv { print $0 }');
fi
#echo "$JOB_LIST"

# FILTER OUT jobs that started after --to value
if [ -n "$TO_VALUE" ]; then
	JOB_LIST=$(echo "$JOB_LIST" | awk -v tv=$TO_VALUE -F"\t" '$2 <= tv { print $0 }');
fi
#echo "$JOB_LIST"

JOB_LIST=$(echo "$JOB_LIST" | awk -F"\t" '{ print $1 }');
JOB_LIST_COUNT=$(echo "$JOB_LIST" | wc -l);


for jobID in ${JOB_LIST}; do

	#echo $jobID;

	jobLine="$jobID";

	# Retrieve the counters corresponding to jobID
	all_counters=$(${bin}/get-job-counters-by-id.sh ${jobID});
	#echo "$all_counters";
	
	# Filter the counter corresponding to CTR_NAME
	CTR_VALUE=$(echo "$all_counters" | grep -e "^$CTR_NAME[[:blank:]]" | cut -d'	' -f4)

	if [ -z "$jobLine" ]; then
		jobLine="$CTR_VALUE";
	else
		jobLine=$(echo -e "$jobLine\t$CTR_VALUE");
	fi

	echo "$jobLine"
done
