# !/bin/sh mlcmd
# Copyright (c) 2024 MarkLogic Corporation
# Initialize a node  - called by /etc/init.d/MarkLogic (or) /etc/MarkLogic/MarkLogic-service.sh on startup 
. init

#
if ! is-managed ; then
  if is-autocreate ; then
     if ! init-autocreate ; then
       error "Failed to create initial user"
     else
      # Dont attempt to create user again on this instance
      [ -f /var/etc/marklogic.conf ] && rm -f /var/etc/marklogic.conf
    fi
  fi
  # not managed - normal startup
  exit 0
fi

HOSTS_URI=/manage/v2/hosts
required $0 MDB_NODE_NAME $MDB_NODE_NAME
HOST=$MARKLOGIC_HOSTNAME
[ -z "$_MDB_TYPE" ] && _MDB_TYPE="$MARKLOGC_MDB_TYPE"

#s=<[ xs:int($MARKLOGIC_NODE_INDEX) * 10 ]>
#message "Sleeping $s"
#sleep $s

# Get original hostname if present
message "Getting node attributes for $MDB_NODE_NAME"
item=mdb-get-attributes()
hostid=<[ $item/hostid/string() ]>
host=<[ $item/host/string() ]>

if [ -z "$host" ] ; then
  message "No host found in mdb" 
  mdb-init-node || error "Failed to initialize MetaData Database with node information" $item
  host=mdb-host()
fi


if ! is-authenticated ; then
  message "Cannot initialize Node without authentication"
  exit 1;
fi

# Mark us as runing
mdb-update-instance-state

function update-hostname()
{
     message "Original host name $host does not match our new host name $HOST" xlocation() ;
     mdb-update newhost $HOST
     hosts=get-cluster-hosts()
     if [ ${#hosts} -eq 0 ] ; then
         message "No cluster hosts online - trying other hosts" xlocation()
         hosts=get-joining-hosts()
         if [ ${#hosts} -eq 0 ] ; then
           message "No known hosts online" xlocation()
           return 1
        fi
     fi
     message "Attempting to rename on the following hosts: $hosts" xlocation()
     for h in $hosts ; do
        message "Attempting to contact $h to rename my hostid $hostid to host $HOST" xlocation()
        if rename-host $h $hostid "$HOST" ; then
            message "Succeeded in renaming my host to $HOST" xlocation()
            mdb-update host $HOST
            mdb-delete-attributes newhost

            return 0
        else
            message "Failed renaming my host via $h" xlocation()
        fi
     done
     message "Failed renaming my host to all online cluster hosts - waiting " xlocation()
     return 1
}


# List of states
# "" or _init      -  initial state with nothing setup except mdb (from init-node)
# init-license-key - License key has been installed
# init-security    - Master created DB or Cluster Joined
# initialized      - Validated that local host is attached to a cluster or locally completed initializaiotn

message "Updating /tmp/marklogic.hosts cache"
update-hosts
message "Checking for initialization state "
while true ; do
   _state=mdb-node-state()
   message "State is $_state"
   case "$_state" in
     "" | _init )
          message "Not previously initialized - initializing license key" xlocation()
          if ! init-license-key ; then
              message "Initialization of license key failed - retrying " xlocation()
              sleep 10;
              if ! init-license-key ; then
                  message "Initialization of license key failed - cannot proceed" xlocation()
                  exit 1;
              fi
          fi
          mdb-update-state init-license-key
          message "Initialization of license key successful" xlocation()
       ;;

      init-license-key )
          if is-master ; then
            if ! init-security  ; then
                message "Failed initializing host - retrying" xlocation()
                sleep 5;
                continue;
             fi
          else
            wait-for-master || error "Failed waiting for master to come online" xlocation()
            message "Joining cluster" xlocation()
            if ! join-master ; then
                 message  "Failed joining to master - retrying " xlocation()
                 sleep-random 5 10 xlocation()
                 continue
            fi
          fi
          mdb-update-state init-security
      ;;

     init-security )

       message "Validating we can contact our host with authentication" xlocation()
       if ! wait-for-startup -secure -host $MARKLOGIC_HOSTNAME ; then
         error "Cannot contact localhost securly - aborting" xlocation()
       fi
       mdb-update-state valid-hostid
       ;;
     valid-hostid )
       hostid=mdb-hostid()
       if [ -z "$hostid" ] ; then
           message "Getting our hostid to update in mdb"
           if ! get-hostid $MARKLOGIC_HOSTNAME $MARKLOGIC_HOSTNAME>{hostid}  ; then
              message "Failed getting hostid - retrying"
              sleep-random 1 5 "get-hostid"
              continue ;
           fi
	   mdb-update hostid $hostid
       fi
       mdb-update-state valid-name
       ;;

     valid-name )
       host=mdb-host()
       if [ "$host" != "$HOST" ] ; then
           if !  update-hostname ; then
             message "Failed to update hostname - waiting to retry " xlocation() ;
            sleep-random 10 20  xlocation()
            continue ;
          fi
        fi
        mdb-update-state initialized
        ;;
     initialized )
       message "Node is initialized - checking for valid name" xlocation()
       if [  "$host" != "$HOST" ] ; then
              mdb-update-state  valid-name
       else
          break;
       fi
       ;;
     *)
       error "Invalid state $_state - aborting"  xlocation() ;;
   esac
done
message "Successfully initialized host $MARKLOGIC_HOSTNAME"
exit 0
