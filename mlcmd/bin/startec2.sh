#!/bin/sh
# Copyright (c) 2020 MarkLogic Corporation 
# This script is ONLY to be called from /etc/init.d/MarkLogic (or) /etc/MarkLogic/MarkLogic-service.sh
# Note that this is run from start_daemon which means that the PATH variable has been reset  

#find out if we are running on AL2 or AL2023
AL2023=0
if [ -f /etc/os-release ] ; then
   AWS_OS_VERSION=`(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | awk -F'"' '{print $2}')`
   if [ "$AWS_OS_VERSION" = 2023 ] ; then
      AL2023=1
   fi
fi

if [ $AL2023 -eq 0 ] ; then
   . /lib/lsb/init-functions
fi
PROG=MarkLogic
export MARKLOGIC_INSTALL_DIR=/opt/MarkLogic
BINARY=$MARKLOGIC_INSTALL_DIR/bin/$PROG

message()
{
   logger -t MarkLogic "$*"
}

unset _MLP # in case previously exported
_MLP="$MARKLOGIC_ADMIN_PASSWORD"
unset MARKLOGIC_ADMIN_PASSWORD 
cd $MARKLOGIC_INSTALL_DIR
message Starting MarkLogic process

#Based on the OS version, the Binary start procedure is modified. 
if [ $AL2023 -eq 1 ] ; then
   $BINARY
   RETVAL=$?
   PID=`cat $MARKLOGIC_PID_FILE`
   echo "${PID}" > $MARKLOGIC_MLCMD_PID_FILE
   if [ $RETVAL -eq 0 ]; then
   message MarkLogic started successfully
   # Initialize license if needed
   # Initialize the Meta Database
   MARKLOGIC_ADMIN_PASSWORD="$_MLP" $MARKLOGIC_INSTALL_DIR/mlcmd/bin/mlcmd -i initialize-node && \
      message MarkLogic initialization successful in ec2
   else
      message MarkLogic failed to start
   fi
else
   start_daemon $BINARY
   RETVAL=$?
   if [ $RETVAL -eq 0 ]; then
   touch /var/lock/subsys/$PROG 2>/dev/null
   [ -z "$INIT_VERSION" ] && log_success_msg
   # Initialize license if needed
   # Initialize the Meta Database
   MARKLOGIC_ADMIN_PASSWORD="$_MLP" $MARKLOGIC_INSTALL_DIR/mlcmd/bin/mlcmd -i initialize-node && \
      echo MarkLogic initialization successful in ec2
   else
      [ -z "$INIT_VERSION" ] && log_failure_msg
   fi
fi
unset _MLP
rm -f $MARKLOGIC_MLCMD_PID_FILE
exit $RETVAL
