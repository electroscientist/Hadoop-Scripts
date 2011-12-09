#!/bin/bash

# This is an automated script for installing a particular version of hadoop
# found in https://github.com/madiator/hadoop-20/ from source.
#
# Author: Megasthenis Asteris
# Created: Dec 7, 2011
#
# DISCLAIMER: Use this script at your own risk. The authors should be not held
# responsible for any damage or loss of data caused by this script.
# :)

# The directory at which hadoop will be installed.
HADOOP_HOME=/usr/local/hadoop

# The username of the dedicated hadoop-installation user
HADOOP_USER=hduser

# If set to 0, then the user login will be disabled. You will be able to connect
# only through ssh (without password), after setting up the ssh-keys 
# appropriately. If set to any other value, then the script will require you
# to type in a password for the new user.
HADOOP_USER_ENABLE_LOGIN=0

# The group name of the dedicated hadoop-installation user
HADOOP_GROUP=hdgroup

# Directory to be used for the hadoop file system
HADOOP_HDFS=/app/hadooo/tmp-${HADOOP_USER}

# Name of the hadoop version you are installing (doesn't really matter)
HADOOP_VERSION_NAME=0.20-fb-mahesh

# The temporary directory used to build hadoop
HADOOP_TMP=/tmp/hadoop_build_$(date +%Y%m%d%H%M%S)

# Installation Process Output Log File
LOG_FILE=output-$(date +%Y%m%d-%H%M%S).log

#==================================================================================================
#==================================================================================================
# Do not edit below this line
#==================================================================================================
#==================================================================================================


# Mark current directory
SCRIPT_DIR=$(pwd)

#==================================================================================================
# Checking if this script is executed with root privileges.
if [[ "$(whoami)" != "root" ]]; then
	echo "Error: should be run with root priviledges. Abort."
	exit 2;
fi
#==================================================================================================
# Installing sun-java-jdk

# Detect the distribution code name. This is necessary when adding the 
# Canonical repository in the sources.lst
echo -ne "- Detecting distribution codename...\t"
distribution_codename=$(lsb_release -c | cut -f2)
if [ -n "${distribution_codename}" ]
then
	echo "OK (${distribution_codename})"
else
	echo "FAIL (${distribution_codename})"
fi

#-------------------------------------------------------------------------------

echo -ne "- Adding Canonical Repository in /etc/apt/sources.list...\t"

FLAG=0;
FLAG=$(grep --count -e "#*[ ]*deb [ ]*http://archive.canonical.com/ [ ]*${distribution_codename} [ ]*partner" /etc/apt/sources.list )
if [ $FLAG -gt 0 ]
then
	eval "perl -pi -e 's{#?\s*deb\s*http://archive.canonical.com/\s*${distribution_codename}\s*partner}{deb http://archive.canonical.com/ ${distribution_codename} partner}g' /etc/apt/sources.list"
	if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
else
	echo "deb http://archive.canonical.com/ ${distribution_codename} partner" >> /etc/apt/sources.list
	if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
fi

#-------------------------------------------------------------------------------
echo -ne "- Updating package tree..\t"
apt-get -q=2 --force-yes update > /dev/null 2>&1
if [ $? -ne 0 ]; then echo "(Warning: Check log file.)"; else echo "OK"; fi

#-------------------------------------------------------------------------------
# Install sun-java6-jdk
echo -ne "- Installing sun-java6-jdk ...\t"
# Set up to overide License Acceptance Prompt
echo sun-java6-jdk shared/accepted-sun-dlj-v1-1 select true | sudo /usr/bin/debconf-set-selections
echo sun-java6-jre shared/accepted-sun-dlj-v1-1 select true | sudo /usr/bin/debconf-set-selections
apt-get -y --allow-unauthenticated --force-yes install sun-java6-jdk >> ${SCRIPT_DIR}/${LOG_FILE} 2>&1
if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi

#-------------------------------------------------------------------------------
# Install sun-java6-plugin
echo -ne "- Installing sun-java6-plugin ...\t"
apt-get -y --allow-unauthenticated --force-yes install sun-java6-plugin > ${SCRIPT_DIR}/${LOG_FILE} 2>&1
if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi

#-------------------------------------------------------------------------------
# Select Sun’s Java as the default on your machine.
echo "- Select sun-java as default java."
update-java-alternatives -s java-6-sun  >> ${SCRIPT_DIR}/${LOG_FILE} 2>&1

echo "- View 'java -version' output:";
echo "------------------------------------";
java -version;
echo "------------------------------------";


#==================================================================================================
# Creating Hadoop-Installation Dedicated user

#------------------------------------------------------------------------------------
# Check if group exists. If not, create it.
if [ -z "$HADOOP_GROUP" ]
then
	echo "Warning: No group not specified."  > /dev/stderr
else
	echo -ne "- Adding new group '${HADOOP_GROUP}'...\t"
	
	# Check if the hadoop-installation-user group exists.
	if [ $(grep -c "^${HADOOP_GROUP}" /etc/group) -eq 0 ]; 
	then
		# If the group does not exist, create it.
		addgroup ${HADOOP_GROUP} > /dev/null 2>&1;
  		if [ $? -eq 0 ]; then echo "OK"; else echo "FAIL"; echo "Abort."; exit 2; fi
  	else
  		echo "OK (Exists)"
  	fi
fi

#-------------------------------------------------------------------------------
# Checking if user already exists. If not, create and add in group.
if [ $(grep -c "^${HADOOP_USER}" /etc/passwd) -gt 0 ];
then
	# If user already exists, use existing user as the dedicated hadoop installation user.
	#deluser ${HADOOP_USER}  > /dev/null 2>&1
	echo "Warning: username for hadoop installation user already exists."
	echo "         Existing user will be used."
else
	# If user does not exist, create a new user to be used as the dedicated hadoop installation user.
	echo -ne "- Adding new user '${HADOOP_USER}'... \t"
	if [ ${HADOOP_USER_ENABLE_LOGIN} -eq 0 ]
	then
		adduser ${HADOOP_USER} --gecos ${HADOOP_USER} --ingroup ${HADOOP_GROUP} --disabled-password > /dev/null 2>&1
		if [ $? -eq 0 ]; then echo "OK"; else echo "FAIL"; echo "Abort."; exit 2; fi
	else
		adduser ${HADOOP_USER} --gecos ${HADOOP_USER} --ingroup ${HADOOP_GROUP}
		if [ $? -eq 0 ]; then echo "OK"; else echo "FAIL"; echo "Abort."; exit 2; fi
	fi
	
fi

#-------------------------------------------------------------------------------
# Add hadoop dedicated user to sudoers (no password)

usermod -a -G admin ${HADOOP_USER}
echo -ne "- Adding ${HADOOP_USER} to sudoers (no password)...\t"
if [ $(grep --count -e "^[ ]*${HADOOP_USER} [ ]*ALL=(ALL) [ ]*NOPASSWD:ALL" /etc/sudoers) -gt 0 ]
then
	echo "(Already added)"
else
	echo "${HADOOP_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
	if [ $? -eq 0 ]; then echo "OK"; else echo "FAIL"; fi
fi

#==================================================================================================
# Generating SSH key for the dedicated hadoop installation user.

#-------------------------------------------------------------------------------
#  Create an RSA key pair with an empty password. 

echo -ne "- Generating a new public ssh-key for the dedicated user...\t"
if [ ! -e "/home/$HADOOP_USER/.ssh/id_rsa" ]
then
	# Empty password is required so that the key can be unlocked without interaction.
	sudo -u $HADOOP_USER rm -f "/home/$HADOOP_USER/.ssh/id_rsa"
	sudo -u $HADOOP_USER ssh-keygen -q -t rsa -P "" -f "/home/$HADOOP_USER/.ssh/id_rsa"
	if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
else
	echo ""
	echo -e "Warning:"
	echo -e "\tFile /home/$HADOOP_USER/.ssh/id_rsa exists."
	echo -e "\tNew key not generated. Using existing key."
	echo -e "\tIf key is not passwordless, execute the following commands:"
	echo "------------------------------------------"
	echo -e "\tsudo -u $HADOOP_USER ssh-keygen -q -t rsa -P \"\" -f \"/home/$HADOOP_USER/.ssh/id_rsa\""
	echo -e "\tsudo -u $HADOOP_USER cat /home/$HADOOP_USER/.ssh/id_rsa.pub >> /home/$HADOOP_USER/.ssh/authorized_keys"
	echo "------------------------------------------"
fi

#-------------------------------------------------------------------------------
# Add the generated key to the authorized keys to enable SSH access 
# to the localhost with this newly created key.
echo -ne "- Adding public key to authorized keys...\t"

if [ -e "/home/$HADOOP_USER/.ssh/authorized_keys" ] && [ $(grep --count -f /home/$HADOOP_USER/.ssh/id_rsa.pub /home/$HADOOP_USER/.ssh/authorized_keys) -gt 0 ]
then
	echo "(Already added.)"
else
	sudo -u $HADOOP_USER cat /home/$HADOOP_USER/.ssh/id_rsa.pub >> /home/$HADOOP_USER/.ssh/authorized_keys
	if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
fi
#-------------------------------------------------------------------------------
# Modify the owner of the ssh directory and authorized_keys file
echo -ne "- Modifying ownershipf of '.ssh'...\t"
chown ${HADOOP_USER}:${HADOOP_GROUP} /home/${HADOOP_USER}/.ssh
if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi

echo -ne "- Modifying ownershipf of '.ssh/authorized_keys'...\t"
chown ${HADOOP_USER}:${HADOOP_GROUP} /home/${HADOOP_USER}/.ssh/authorized_keys
if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi

#-------------------------------------------------------------------------------
# Attempt to establish an ssh connection to the localhost in order to accept the Authentication key
echo -ne "- Test ssh to localhost...\t"
sudo -u $HADOOP_USER ssh -o StrictHostKeyChecking=no localhost ' ' >> ${SCRIPT_DIR}/${LOG_FILE} 2>&1 # just try to connect. but do nothing
if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi

#==================================================================================================
# Hadoop Installation

#-------------------------------------------------------------------------------
# Create the temporary directory where hadoop will be build
if [ -d "${HADOOP_TMP}" ]; then rm -rf "${HADOOP_TMP}"; fi
mkdir ${HADOOP_TMP}

echo -ne "- Entering temporary hadoop build dir...\t"
cd  ${HADOOP_TMP}
if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi

#-------------------------------------------------------------------------------
# Download the git-core tool if not present

which git > /dev/null
if [ $? -ne 0 ];
then
	echo -ne "- Downloading git-core...\t"
	sudo apt-get -y --allow-unauthenticated --force-yes install git-core >> ${SCRIPT_DIR}/${LOG_FILE} 2>&1
	if [ $? -ne 0 ]; then echo "FAIL"; echo "Abort."; exit 1; else echo "OK"; fi
fi

#-------------------------------------------------------------------------------
# Download hadoop src from github

echo -ne "- Get a fresh copy from the git repository...\t"
git clone https://github.com/madiator/hadoop-20.git . >> ${SCRIPT_DIR}/${LOG_FILE} 2>&1
if [ $? -ne 0 ]; then echo "FAIL"; echo "Abort."; exit 1; else echo "OK"; fi

echo -ne "- List git branches...\t"
git branch -a >> ${SCRIPT_DIR}/${LOG_FILE}  2>&1;
if [ $? -ne 0 ]; then echo "FAIL"; echo "Abort."; exit 1; else echo "OK"; fi

echo -ne "- Checkout regeneratingcode...\t"
git checkout -b regeneratingcode origin/regeneratingcode >> ${SCRIPT_DIR}/${LOG_FILE}  2>&1
if [ $? -ne 0 ]; then echo "FAIL"; echo "Abort."; exit 1; else echo "OK"; fi

#-------------------------------------------------------------------------------
# Modify the 'build.properties' configuration file
if [ -e "${HADOOP_TMP}/build.properties" ];
then
	eval "perl -pi -e 's/^\s*version=.*/version=${HADOOP_VERSION_NAME}/g' ${HADOOP_TMP}/build.properties"
	#cat ${HADOOP_TMP}/build.properties 
else
	echo "Warning: build.properties not found."
fi

#-------------------------------------------------------------------------------
# Skip this step (already done)
# cd ${HADOOP_TMP}/src/contrib/raid/
# ln -s ../../../build.properties build.properties

#-------------------------------------------------------------------------------
# Download the ant tool if not present

which ant > /dev/null
if [ $? -ne 0 ];
then
	echo -ne "- Downloading ant..\t"
	sudo apt-get -y --allow-unauthenticated --force-yes install ant >> ${SCRIPT_DIR}/${LOG_FILE} 2>&1
	if [ $? -ne 0 ]; then echo "FAIL"; echo "Abort."; exit 1; else echo "OK"; fi
fi
#-------------------------------------------------------------------------------
# Build Hadoop from source
echo -ne "- Building (ant) hadoop...\t"
cd ${HADOOP_TMP}
ant >> ${SCRIPT_DIR}/${LOG_FILE} 2>&1
if [ $? -ne 0 ]; then echo "FAIL"; echo "Abort."; exit 1; else echo "OK"; fi

echo -ne "- Building raid package...\t"
cd ${HADOOP_TMP}/src/contrib/raid
ant package -Ddist.dir=${HADOOP_TMP}/build >>  ${SCRIPT_DIR}/${LOG_FILE} 2>&1
if [ $? -ne 0 ]; then echo "FAIL"; echo "Abort."; exit 1; else echo "OK"; fi

#-------------------------------------------------------------------------------
# EDIT HADOOP CONFIGURATION FILES
#-------------------------------------------------------------------------------

# Download xmlstarlet tool to edit xml files.
which xmlstarlet > /dev/null
if [ $? -ne 0 ];
then
	echo "- Downloading xmlstarlet to edit xml configuration files.."
	sudo apt-get -y --allow-unauthenticated --force-yes install xmlstarlet >> ${SCRIPT_DIR}/${LOG_FILE} 2>&1
	if [ $? -ne 0 ]; then echo "FAIL"; echo "Abort."; exit 1; else echo "OK"; fi
fi

#**********************************
# /conf/hadoop-env.sh file
#**********************************

echo -ne "- Modifying /conf/hadoop-env.sh ...\t"
if [ -e "${HADOOP_TMP}/conf/hadoop-env.sh" ]
then	
	FLAG=0;
        eval "perl -pi -e 's/^\s*export\s*HADOOP_USERNAME=.*/export HADOOP_USERNAME=${HADOOP_USER}/g' ${HADOOP_TMP}/conf/hadoop-env.sh"
	if [ $? -ne 0 ]; then let FLAG+=1; fi
        eval "perl -pi -e 's/^\s*#?\s*export\s*JAVA_HOME=.*/export JAVA_HOME=\057usr\057lib\057jvm\057java-6-sun/g' ${HADOOP_TMP}/conf/hadoop-env.sh"
	if [ $? -ne 0 ]; then let FLAG+=1; fi
        eval "perl -pi -e 's{^\s*#?\s*export\s*HADOOP_CLASSPATH=.*}{export HADOOP_CLASSPATH=\044{HADOOP_HOME}/build/contrib/raid/hadoop-${HADOOP_VERSION_NAME}-raid.jar}g' ${HADOOP_TMP}/conf/hadoop-env.sh"
	if [ $? -ne 0 ]; then let FLAG+=1; fi
        if [ $FLAG -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
else
        echo "Warning: ${HADOOP_TMP}/conf/hadoop-env.sh not found."
fi
#cat ${HADOOP_TMP}/conf/hadoop-env.sh

#**********************************
# /conf/hdfs-site.xml
#**********************************

cp ${HADOOP_TMP}/conf/hdfs-site.xml ${HADOOP_TMP}/conf/hdfs-site.xml.backup
xmlstarlet edit -u "/configuration/property[name='dfs.permissions']"/value -v 'false' ${HADOOP_TMP}/conf/hdfs-site.xml.backup > ${HADOOP_TMP}/conf/hdfs-site.xml

#-------------------------------------------------------------------------------
# Create the directory where all of Hadoop's temporary files will be stored.
if [ ! -d "${HADOOP_HDFS}" ]
then
	mkdir -p ${HADOOP_HDFS}
fi
chown -R ${HADOOP_USER}:${HADOOP_GROUP} ${HADOOP_HDFS}
cp ${HADOOP_TMP}/conf/core-site.xml ${HADOOP_TMP}/conf/core-site.xml.backup
xmlstarlet edit -u "/configuration/property[name='hadoop.tmp.dir']"/value -v $(echo "${HADOOP_HDFS}") ${HADOOP_TMP}/conf/core-site.xml.backup > ${HADOOP_TMP}/conf/core-site.xml

chown -R ${HADOOP_USER}:${HADOOP_GROUP} ${HADOOP_HOME}

#-------------------------------------------------------------------------------
# Copying Hadoop compiled files to the permanent installation directory
# (indicated by the HADOOP_HOME variable)

echo -ne "- Copying files to ${HADOOP_HOME} ...\t"
if [ -d "${HADOOP_HOME}" ]; then rm -rf ${HADOOP_HOME}; fi
mkdir ${HADOOP_HOME}
cp -rf ${HADOOP_TMP}/* ${HADOOP_HOME}/
if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi

chown -R ${HADOOP_USER}:${HADOOP_GROUP} ${HADOOP_HOME}

#-------------------------------------------------------------------------------
# Edit .bashrc file

echo "- Editing .bashrc:"

FLAG=0;

echo -ne "   > HADOOP_HOME=${HADOOP_HOME}...\t"
if [ $(grep --count -e "^[ ]*export [ ]*HADOOP_HOME=${HADOOP_HOME}" /home/$HADOOP_USER/.bashrc) -gt 0 ]
then
	echo "(Already Set)"
else
	echo "# Set Hadoop-related environment variables
export HADOOP_HOME=$HADOOP_HOME" >> /home/$HADOOP_USER/.bashrc
	if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
	FLAG=1;
fi


echo -ne "   > JAVA_HOME...\t"
if [ $(grep --count -e "^[ ]*export [ ]*JAVA_HOME=/usr/lib/jvm/java-6-sun" /home/$HADOOP_USER/.bashrc) -gt 0 ]
then
	echo "(Already Set)"
else
	echo '# Set JAVA_HOME (we will also configure JAVA_HOME directly for Hadoop later on)
export JAVA_HOME=/usr/lib/jvm/java-6-sun' >> /home/$HADOOP_USER/.bashrc
	if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
fi

echo -ne "   > Add Hadoop bin to PATH...\t"
if [ $(grep --count -e "^[ ]*export [ ]*PATH=\$PATH:\$HADOOP_HOME/bin" /home/$HADOOP_USER/.bashrc) -gt 0 ] && [ $FLAG -eq 0 ]
then
	echo "(Already Set)"
else
	echo '# Add Hadoop bin/ directory to PATH
export PATH=$PATH:$HADOOP_HOME/bin' >> /home/$HADOOP_USER/.bashrc
	if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
fi

source /home/$HADOOP_USER/.bashrc


#==================================================================================================
echo "- Modify Additional Scripts"

eval "perl -pi -e 's{dfs\.data\.dir=.*/dfs}{dfs\.data\.dir=${HADOOP_HDFS}/dfs}g' ${HADOOP_HOME}/bin/extra-local-datanodes.sh"


#-------------------------------------------------------------------------------
# End of Script
#-------------------------------------------------------------------------------
echo "** Installation Finished. **"
echo -ne "- Removing temporary files...\t"
rm -rf ${HADOOP_TMP}
if [ $? -ne 0 ]; then echo "FAIL"; else echo "OK"; fi
echo "Warning: Open a new bash to run hadoop."

echo "------------------------------------------------"
echo "For more info check output log:"
echo "${SCRIPT_DIR}/${LOG_FILE}"
echo "------------------------------------------------"


