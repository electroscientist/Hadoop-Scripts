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


#-------------------------------------------------------------------------------
# Stop all runnning hadoop daemons and wait till they have stopped

# Check if any of the hadoop daemnos are running
daemonsRunning=$(jps | egrep -i 'namenode|datanode|tasktracker|jobtracker|raidnode' | wc -l);
if [ ${daemonsRunning} -gt 0 ]; then
	echo "warn: hadoop services running (- jps)."

	read -n1 -p "Stop all services (y/n)?"
	if [ "$REPLY" == "y" ]; then
		${HADOOP_HOME}/bin/stop-all.sh
		datanodesStillUp=$(jps | egrep -i 'datanode' | wc -l);
		if [ ${datanodesStillUp} -gt 0 ]; then
			${HADOOP_HOME}/bin/extra-local-datanodes.sh stop $(seq 1 $datanodesStillUp)
		fi
		echo ""
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

fi

#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Compile source code and package the raid classes
read -n1 -p "Compile Code (y/n)?"
if [ "$REPLY" == "y" ]; then
	cd ${HADOOP_HOME}
	ant
	cd -
	cd ${HADOOP_HOME}/src/contrib/raid/; 
	ant package -Ddist.dir=$HADOOP_HOME/build;
	cd -
fi


#-------------------------------------------------------------------------------
# Format file-system, back up logs and clean log directory.
echo "format all"
${HADOOP_HOME}/format-all.sh
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Start hadoop daemons and extra datanodes

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
if [ $ATTEMPTS -eq 0 ] && [ $alive -le $HADOOP_NUM_OF_EXTRA_DATANODES ]; then 
	echo " (time out)"
else
	echo ""
fi
echo "$alive datanodes awake."

#-------------------------------------------------------------------------------


echo "put a file: $FILENAME"
${HADOOP_HOME}/bin/hadoop dfs -put /app/hadoop/data/bob640.dat $FILENAME

#-------------------------------------------------------------------------------
echo -n "Wait for raid.."
# Wait for all blocks to get replication equal to 1.
ATTEMPTS=$(($SEC_TO_WAIT_FOR_RAID/5))
while [ $ATTEMPTS -gt 0 ]; do
	let ATTEMPTS-=1
	
	res=$(${HADOOP_HOME}/check-if-raided.sh $FILENAME);
	if [ $? -ne 0 ]; then echo "error"; fi

	if [ "$res" == "no" ]; then
		echo -n "."
		sleep 5;
		continue;
	elif [ "$res" == "yes" ]; then
		echo " done"
		break;
	else
		echo "unhandled situation: debug : res=$res"
		exit 1;
	fi
done
if [ $ATTEMPTS -eq 0 ] && [ "$res" == "no" ]; then 
	echo " (time out)"
fi
#-------------------------------------------------------------------------------

