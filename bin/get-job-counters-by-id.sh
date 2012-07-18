#!/usr/bin/env bash

# Prints a list of the job counters and their values.
# The output consists of four columns separated by a tab.
# The first column is the counter's name and the following three columns are
# the counter's value during the map phase, reduce phase and total job duration
# respectively.
#
# Although hadoop provides a command-line to obtain counter values, this script
# fetches counter values from the job's tracking url (job tracker's web 
# itnerface). The reason is twofold:
# - job status from command line ("hadoop job -status jobid") returns the
#   counters only for running or recently completed jobs (not retired jobs).
# - Also, although it returns the most valuable counters, it has limited
#   information compared to the web-interface.

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

# if no args specified, show usage
if [ $# -ne 1 ]; then
	echo -e 'Usage:   get-job-counters-by-id "JOBID"'
	echo -e '         JOBID is the id of a job as it appears in "hadoop jobs -list all".'
	echo -e "Example: get-job-counters-by-id job_201207171401_0094"
	echo -e "Output:  <Counter Name 1>\t<Map>\t<Reduce>\t<Total>"
	echo -e "         <Counter Name 2>\t<Map>\t<Reduce>\t<Total>"
	echo -e "         <Counter Name 3>\t..."
	exit 1;
fi

JOB_ID="$1";
REPORT=$(${HADOOP_HOME}/bin/hadoop job -status $JOB_ID);
URL=$(echo "$REPORT" | grep "tracking URL:" | cut -d' ' -f3); 
#echo $URL;

if [ -n "$URL" ]; then
	${bin}/get-job-counters-by-url.sh "$URL"
else
	echo "could not determing tracking url" >&2;
	exit 1;
fi
