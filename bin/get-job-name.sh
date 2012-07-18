#!/usr/bin/env bash


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

JOB_ID=$1

REPORT=$(hadoop job -status $JOB_ID);
URL=$(echo "$REPORT" | grep "tracking URL:" | cut -d' ' -f3); 
#echo $URL;

echo $URL | xargs -n 1 -I{} sh -c "curl -s -XGET {} | grep 'Job Name' | sed 's/.* //' | sed 's/<br>//'"

