#!/usr/bin/env bash

# Return the name of a job, given a job id.
# Job id is the id as it appears using the following command:
# $ hadoop job -list all
# The job name is only available through the tracking URL (job tracker's web
# interface). The url is fetched and parsed to retrieve the job name.

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

# if no args specified, show usage
if [ $# -ne 1 ]; then
  echo "Usage: get-job-name-by-id ID"
  echo "       ID is the job's id."
  echo "		(job ids can be found with: hadoop job -list all"
  echo "Example: get-job-name-by-id job_201207171401_0094"
  exit 1
fi

JOB_ID="$1";

JOB_REPORT=$(${HADOOP_HOME}/bin/hadoop job -status "$JOB_ID");
JOB_URL=$(echo "$JOB_REPORT" | grep "tracking URL:" | cut -d' ' -f3); 
#echo $JOB_URL;

if [ -n "$JOB_URL" ]; then
	echo $JOB_URL | xargs -n 1 -I{} sh -c "curl -L -s -XGET {} | grep 'Job Name' | sed 's/.* //' | sed 's/<br>//'"
else
	echo "could not determing tracking url" >&2;
	exit 1;
fi

exit 0;

