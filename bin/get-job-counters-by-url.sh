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
	echo -e 'Usage:   get-job-counters-by-url "JOBURL"'
	echo -e '         JOBURL is the the tracking url of the job.'
	echo -e 'Example: get-job-counters-by-url "http://localhost:50030/jobdetails.jsp?jobid=job_201207171401_0094"'
	echo -e 'Output:  <Counter Name 1>\t<Map>\t<Reduce>\t<Total>'
	echo -e '         <Counter Name 2>\t<Map>\t<Reduce>\t<Total>'
	echo -e '         <Counter Name 3>\t...'
	exit 1;
fi


JOB_URL="$1";
#echo $JOB_URL

JOB_REPORT_WEBPAGE=$(curl -L -s -XGET "$JOB_URL");
if [ $? -ne 0 ]; then echo "error fetching job url" >&2; exit 1; fi
#echo $JOB_REPORT_WEBPAGE

# Preprocess the html source to bring all <td>s of each counter in the same line
processed=$(echo "$JOB_REPORT_WEBPAGE" | perl -p -e 's/td>\s*\n/td>/g;s/\s*<td/<td/g;s|</tr>||g');
#echo $processed

# Exploit the structure of the html table that contains the counters to retrieve
# the counter names and corresponding values.
echo "$processed"  | perl -lne 'm|<td>([^<]+)</td><td align="right">(.+)</td><td align="right">(.+)</td><td align="right">(.+)</td>|g&&print "$1\t$2\t$3\t$4"'

exit 0;


