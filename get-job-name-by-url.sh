#!/usr/bin/env bash

# Return the name of a job, given a job's tracking url.
# Job tracking url is the url of the job's report in the job tracker's web
# interface. It can also be found using the command line:
# $ hadoop job -status JOBID
# where JOBID is the job's id.
# The job name is only available through the tracking url (job tracker's web
# interface). The url is fetched and parsed to retrieve the job name.

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

# if no args specified, show usage
if [ $# -ne 1 ]; then
  echo "Usage: get-job-name-by-url URL"
  echo "       URL is the the tracking url of the job."
  echo "Example: get-job-name-by-url http://localhost:50030/jobdetails.jsp?jobid=job_201207171401_0094"
  exit 1
fi

URL="$1"

echo "$URL" | xargs -n 1 -I{} sh -c "curl -L -s -XGET {} | grep 'Job Name' | sed 's/.* //' | sed 's/<br>//'"

