# ec2-startup
# Copyright (c) 2024 MarkLogic Corporation 
# Startup script on every launch of MarkLogic
##
## This is called from /etc/MarkLogic/init.d (or) /etc/MarkLogic/MarkLogic-service.sh in the parent startup process prior to 
## launching MarkLogic 
## After this completes then $MARKLOGIC_INSTALL/bin/startec2.sh is started as a daemon 
## and MarkLogic starts as a daemon.  startec2.sh then calls  
##   $MARKLOGIC_INSTALL_DIR/mlcmd/bin/mlcmd -i initialize-node
## If this function exits <>0 then ML is not started at all (unrecoverable error)
## The main purpose is to synchronize the device status in the system to/from MDB
## 

. init

_mount=/var/opt/MarkLogic

# legacy startup - no auto management
if ! is-managed ; then
 # if /var/opt/MarkLogic is already a mountpoint then use it
  if mountpoint -q $_mount  ; then
    message "Mountpoint $_mount is already mounted - use it"
    exit 0
  fi
  dev=get-os-device-name($MARKLOGIC_EBS)
  message "Instance is not managed"
  
  wait_time="PT30S";
  [ -n "$MARKLOGIC_BOOT_WAIT" ] && wait_time="PT${MARKLOGIC_BOOT_WAIT}S"
  wait_end=<[ fn:current-dateTime() + xs:dayTimeDuration($wait_time)  ]> 
  message "Waiting for device mounted to come online : $dev"
  while [ ! -b $dev ] ;  do
   [ <[ fn:current-dateTime() gt $wait_end ]> ] && 
      error "Volume $MARKLOGIC_EBS has failed to attach - aborting"
    sleep 10
  done
  mount-volume $MARKLOGIC_EBS /var/opt/MarkLogic || error "Failed to mount EBS volume - aborting"
else
  message "Managed Cluster startup"
  _state=mdb-node-state()
  message "Current initialized state is $_state"
  if [ "$_state" = "initialized" ] ; then 
    message "Previously initialized - updating system from MDB"
    sync-volumes-from-mdb || error "Stopping initialization - cannot initialize all volumes"
  else 
    ## System not fully initialized but may have aborted part way up.
    ## 
    ## If there are any devices in mdb then attempt to sync from them first 
    if mdb-has-device-entries ; then 
       message "MDB has previous device entries - attempting to attach"
       if ! sync-volumes-from-mdb ; then
          message "Failed to attach devices - Initializing from current state of system"
          init-volumes-from-system || error "Stopping initialization - cannot initialize all volumes"
       fi
    fi    
    message "Initializing from current state of system"
    init-volumes-from-system || error "Stopping initialization - cannot initialize all volumes"
  fi
fi

