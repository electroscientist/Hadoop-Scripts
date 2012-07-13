#!/usr/bin/env bash

# Just to automate a few things...
# - kill all running hadoop-daemons
# - format the filesystem, delete logs (using format-all.sh)
# - restart the daemons
# - wait for datanodes to go up
# - put a file
# - wait for the file to be raided



HADOOP_USER=hduser
HADOOP_NUM_OF_EXTRA_DATANODES=5
FILENAME=/user/$HADOOP_USER/bob.dat
SEC_TO_WAIT_FOR_DATANODES_TO_WAKE=120
SEC_TO_WAIT_FOR_RAID=120


daemonsRunning=$(jps | egrep -i 'namenode|datanode|tasktracker|jobtracker|raidnode' | wc -l);
if [ ${daemonsRunning} -gt 0 ]; then
	echo "warn: services running (run jps). Stop all before formatting."
fi

read -n1 -p "Stop all services (y/n)?"
if [ "$REPLY" == "y" ]; then
	${HADOOP_HOME}/bin/stop-all.sh
	datanodesStillUp=$(jps | egrep -i 'datanode' | wc -l);
	if [ ${datanodesStillUp} -gt 0 ]; then
		${HADOOP_HOME}/bin/extra-local-datanodes.sh stop $(seq 1 $datanodesStillUp)
	fi
else
	echo "exit"
	exit 0;
fi


echo -n "Wait for daemons to go down.."
MAX_WAIT_SEC=60
while [ $MAX_WAIT_SEC -gt 0 ]; do
	let MAX_WAIT_SEC-=1
	daemonsRunning=$(jps | egrep -i 'namenode|datanode|tasktracker|jobtracker|raidnode' | wc -l);
	if [ $daemonsRunning -gt 0 ]; then
		echo -n "."
		sleep 1;
		continue;
	fi
	echo ""
	break;
done

read -n1 -p "Compile Code (y/n)?"
if [ "$REPLY" == "y" ]; then
	cd ${HADOOP_HOME}
	ant
	cd -
	cd ${HADOOP_HOME}/src/contrib/raid/; 
	ant package -Ddist.dir=$HADOOP_HOME/build;
	cd -
fi



echo "format all"
${HADOOP_HOME}/format-all.sh


${HADOOP_HOME}/bin/start-all.sh
${HADOOP_HOME}/bin/extra-local-datanodes.sh start $(seq 1 $HADOOP_NUM_OF_EXTRA_DATANODES)

echo -n "Waiting for nodes to go up.."


ATTEMPTS=$(($SEC_TO_WAIT_FOR_DATANODES_TO_WAKE/2))
while [ $ATTEMPTS -gt 0 ]; do
	let ATTEMPTS-=1
	alive=$(${HADOOP_HOME}/get_number_of_datanodes.sh | grep "Alive" | cut -d':' -f2)
	if [ $alive -le $HADOOP_NUM_OF_EXTRA_DATANODES ]; then
		echo -n "."
		sleep 2;
		continue;
	fi
	break;
done
echo
echo "$alive datanodes awake."
if [ $ATTEMPTS -eq 0 ] && [ $alive -le $HADOOP_NUM_OF_EXTRA_DATANODES ]; then 
	echo "time out"
fi

echo "put a file: $FILENAME"
${HADOOP_HOME}/bin/hadoop dfs -put /app/hadoop/data/bob640.dat $FILENAME

echo -n "Wait for raid.."
#count the number of blocks with replication more than 1
COUNT="${HADOOP_HOME}/bin/hadoop fsck $FILENAME -files -blocks -locations 2>/dev/null | grep blk_ | cut -d' ' -f4 | cut -d'=' -f2 | grep -c 1 --invert"
# Wait for all blocks to get replication equal to 1.
SEC_TO_WAIT_FOR_RAID=60
ATTEMPTS=$(($SEC_TO_WAIT_FOR_RAID/5))
while [ $ATTEMPTS -gt 0 ]; do
	let ATTEMPTS-=1
	#count the number of blocks with replication more than 1
	replicated=$(eval $COUNT)
	if [ $replicated -gt 0 ]; then
		echo -n "."
		sleep 5;
		continue;
	else
		echo "raid over."
		break;
	fi
	echo "time out"
	exit 1;
done




