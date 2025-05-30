# init-config
# Copyright (c) 2024 MarkLogic Corporation
# Save MARKLOGIC_NODE_NAME before .init which reads
#   the mlcmd config file /var/local/mlcmd.conf
# Since stdout is used for the config file, all outupt that is not intended for  
# the config needs to be redirected.  
# Encapsulate the main body in a function and redirect its output so extraneous
# errors and other output doesnt find its way to the config file
# stderr is fine to print to stderr
##


# Run everything in a block
{
. init  

### This is the only function that should write to stdout 
function setvalue()
{
   local var=$1
   shift
   local value=quote("$*")
   message "Set configuration: $var=$value"
   echo -p cport "$var=$value"
}

##
## Main function 
## 

function run-init-config()
{
  log "runing init-config.xsh"

  #
  ## Set current JAVA_HOME if defined
  ##
  #
  [ -D JAVA_HOME -a -n "$JAVA_HOME" ]  && setvalue JAVA_HOME "$JAVA_HOME"

  setvalue MARKLOGIC_MDB_TYPE  $_MDB_TYPE
  
  AWS_REGION=$(ec2-get-region)
  _ZONE=$(ec2-get-meta placement/availability-zone)
  INSTANCE=$(ec2-get-meta instance-id)
  setvalue AWS_REGION $AWS_REGION
  setvalue AWS_DEFAULT_REGION $AWS_REGION
  setvalue MARKLOGIC_ZONE $_ZONE
  setvalue MARKLOGIC_HOSTNAME $MARKLOGIC_HOSTNAME
  
  message "Initialize Configuration." "AWS Region: $AWS_REGION, ZONE: $_ZONE. INSTANCE: $INSTANCE"
  if [ -n "$MARKLOGIC_NODE_NAME" ] ; then
  	message "Configured node name. MARKLOGIC_NODE_NAME: $MARKLOGIC_NODE_NAME"
  fi
  
  local fstype=get-default-fstype()
  [ -n "$fstype" ] && setvalue MARKLOGIC_FSTYPE $fstype
  
  # is-managed requires MARKLOGIC_CLUSTER_NAME and MARKLOGIC_NODE_NAME
  if ! is-managed  ; then
    if [ -n "$MARKLOGIC_ADMIN_AUTOCREATE" ] ; then
      message "Initializing with auto user create"
      [ -z "$MARKLOGIC_ADMIN_USERNAME" ] && MARKLOGIC_ADMIN_USERNAME=admin
      setvalue MARKLOGIC_ADMIN_USERNAME "$MARKLOGIC_ADMIN_USERNAME"
      setvalue MARKLOGIC_ADMIN_AUTOCREATE "$MARKLOGIC_ADMIN_AUTOCREATE"
    fi
    exit 0
  fi
  
  ## From this point we need a database
  
  mdb-valid  || error "Internal error: managed cluster without a configured MDB Database"
  setvalue MARKLOGIC_MDB_TYPE  $_MDB_TYPE
  
  # non managed nodes do no pre configuration
  message "Managed cluster initialization"
  
  # Use the pre-localized name
  _NAME=$MARKLOGIC_NODE_NAME
  _INDEX=1
  
  _NAME=localize-node-pattern( "$_NAME"  "$_ZONE" )
  
  message "Localized name pattern to $_NAME"
  
  # Find or create cluster
  if mdb-domain-exists $MDB_NAME ; then
     message "Found existing $MDB_DESC $MDB_NAME" ;
  else
     error No MDB found: $MDB_NAME - aborting
  fi
  _FOUND=0
  
  message  "MARKLOGIC_INSTANCE:$MARKLOGIC_INSTANCE INSTANCE:$INSTANCE MDM_NODE_NAME: $MDM_NODE_NAME MARKLOGIC_NODE_NAME: $MARKLOGIC_NODE_NAME MARKLOGIC_ZONE:$MARKLOGIC_ZONE ZONE: $_ZONE"
  
  # If this is a restart or reboot we may already have configured ourselves
  if ! is-node-pattern "$MARKLOGIC_NODE_NAME" &&
     [  "$MARKLOGIC_INSTANCE" = "$INSTANCE"  -a -n "$MDB_NODE_NAME"  \
         -a  "$MARKLOGIC_ZONE" = "$_ZONE"  ] ; then
  
     _a=mdb-get-attributes()
     message "Attribute information for node: $MDB_NODE_NAME" {$_a}
     _instance=mdb-get-attr-string( $_a  instance )
     if  [ "$_instance" = "$MARKLOGIC_INSTANCE"  ] ; then
            # Use localized non patterned hostname
         _NAME=mdb-get-attr-string( $_a node )
         _INDEX=mdb-get-attribute( $_a index )
         _host=mdb-get-attr-string( $_a host )
         message "Restarted with same instance: $_instance, nodename: $_NAME and hostname: $_host"
         _FOUND=1
     fi
  fi
  
  if [ "$_FOUND" = 0 ] ; then
  
    local instance
    # Find node
    if is-node-pattern "$_NAME" ; then
      trace $0 node-pattern $_NAME
      local _a
      _a=mdb-get-attributes-from-instance( $INSTANCE )
      _N=mdb-get-attribute( $_a node )
      
      #find hostname of the current host from secondary network interface.
      GET_ENI=0
      [ "$MARKLOGIC_MANAGED_NODE" = "1" ] && [ -n "$MARKLOGIC_CLUSTER_NAME" -a -n "$MARKLOGIC_NODE_NAME" ] \
        && GET_ENI=1

      if [ "$GET_ENI" = 1 ] ; then
        if [ -z "$ENI_HOSTNAME" ] ; then
            message "Detecting secondary network interface"
            MAX_RETRIES=20
            RETRY_COUNT=0

            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                MACS=$(ec2-get-meta network/interfaces/macs/)
                for _MAC in $MACS; do
                    _DEVICE=$(ec2-get-meta network/interfaces/macs/$_MAC/device-number)
                    if [ "$_DEVICE" = "1" ]; then
                        ENI_HOSTNAME=$(ec2-get-meta network/interfaces/macs/$_MAC/local-hostname)
                        if [ -z "$ENI_HOSTNAME" ]; then
                            ENI_HOSTNAME=$(ec2-get-meta network/interfaces/macs/$_MAC/local-ipv4s)
                        fi
                        if [ -n "$ENI_HOSTNAME" ]; then
                            message "Successfully detected secondary network interface: $ENI_HOSTNAME"
                            break 2
                        fi
                    fi
                done

                # Added Retry and more sleep time for new detach logic added to CFT Node Manager Lambda Fucntion
                # To wait for the secondary network interface to be attached to the node
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -le 5 ]; then
                    SLEEP_INTERVAL=5
                elif [ $RETRY_COUNT -le 10 ]; then
                    SLEEP_INTERVAL=10
                elif [ $RETRY_COUNT -le 15 ]; then
                    SLEEP_INTERVAL=15
                else
                    SLEEP_INTERVAL=20
                fi

                message "Device-number 1 not available. Retrying in $SLEEP_INTERVAL seconds (Attempt $RETRY_COUNT/$MAX_RETRIES)"
                sleep $SLEEP_INTERVAL
            done
        else
          message "ENI_HOSTNAME is already present so we skipped the secondary network interface detection"
        fi
      else
        message "try secondary network interface is 0 so skipping"
      fi
     
      #find nodename with the hostname 
      if [ ! -z "$ENI_HOSTNAME" ] ; then 
        _N=mdb-get-nodename-with-hostname($ENI_HOSTNAME)
	#bug:55948
	if [ -z "$_N" ] ; then 
          message "Node name wasnt retrieved with ENI_hostname. Using MARKLOGIC_HOSTNAME for DDB search"
          _N=mdb-get-nodename-with-hostname($MARKLOGIC_HOSTNAME)
          message "Node name retrieved from DDB using MARKLOGIC_HOSTNAME :  $_N" 
        fi
        #bug:55948
        _exist_ddb=$_N
        message "Node name retrieved from DDB:  $_N" 
      else
        message "Hostname from secondary network interface is not found, so nodename will be calculated"
      fi 
 
      if [ -n "$_N" ] && mdb-update-if-equals "$_N"  instance  "$INSTANCE"  \
              create-date <[ fn:current-dateTime() ]>   zone "$_ZONE" >/dev/null ; then
        message "Found previous node for my instance: $_N"
        _NAME=$_N
        _INDEX=mdb-get-attribute( $_a index )
      else
        message "Searching for a free node name with pattern $_NAME"
  
       # Look first in nodes which have MDB entries then in free nodes
        idxs=mdb-get-index-in-zone($_ZONE)
        for i in <[ fn:distinct-values( ($idxs , (1 to 100))) ]> ; do
         if [ -z "$_exist_ddb" ] ; then
          _N=replace-node-pattern( $_NAME $i )
         fi
	 message "Checking for free node $_N instance $INSTANCE"
         attributes=mdb-get-attributes-for-node( "$_N" )
         if  mdb-attr-blank $attributes node ; then
           message "Found unused Node $_N trying to allocate"
           if mdb-allocate-node "$_N" "$INSTANCE" "$_ZONE" ; then
               trace $0 "attach node succeeded" $_N $i 
              _NAME=$_N
              _INDEX=$i
              break
              trace $0 SNH - after break
           fi
           trace $0 "attach node failed" $_NAME $_INDEX
         else
            _instance=mdb-get-attr-string( $attributes instance )
            if [ "$_instance" = "$INSTANCE" ] ; then
               message "Found Node $_N for my instance $INSTANCE"
              _NAME=$_N
              _INDEX=$i
              break
            fi

            # Possible EC2 states
            # pending running shutting-down terminated stopping stopped rebooting
            _state=instance-state($_instance)
            message "Checking for instance state instance: $_instance state: $_state"

            # bug:56218 55780 57705
            if [ "$_state" = "shutting-down" ] ; then
              TERMCOUNTER=1
              while [ $TERMCOUNTER -le 20 ] ; do
                  message "Waiting for $_instance to completely shut down. Retry $TERMCOUNTER of 20"
                  sleep 10
                  shutdownstate=instance-state($_instance)
                  if [ "$shutdownstate" = "shutting-down" ] ; then
                    TERMCOUNTER=$(expr $TERMCOUNTER + 1)
                  else
                    break ;
                  fi 
              done
              _termresponse=terminate-instance($INSTANCE)
              message "Response from terminate instance function: $_termresponse"
              exit 0
            fi
  
            case "$_state" in
              running|stopped|pending|rebooting) 
                 message "Instance $_instance is in use: state $_state"  ; continue  ;;
  
              terminated) 
                message "Instance $_instance is terminated - taking over name. "
                 if ! mdb-update-if-equals "$_N" instance "$_instance"  zone $_ZONE \
                         instance "$INSTANCE" create-date <[ fn:current-dateTime() ]> >{r} ; then
                    message "Failed taking on node name $_N ... keep searching" {$r}
                    continue ;
                fi 
                ;;
  
              *) message "Instance $_instance is in an unknown state : $_state"
                _DATE=mdb-get-attr-datetime( $attributes create-date)
                if [ <[ exists( $_DATE ) and $_DATE gt  ( fn:current-dateTime() - 
                          xs:dayTimeDuration("PT2M") ) ]> ] ; then
                     message "Node record created too recently, skipping: state: $_state date: $_DATE"
                     continue ;
                fi
                # do not specify "node" as its both a key and a field 
               if ! mdb-update-if-equals "$_N" instance "$_instance"  zone $_ZONE \
                      instance "$INSTANCE" create-date <[ fn:current-dateTime() ]> >{r} ; then
                  message "Failed taking on node name $_N ... keep searching" {$r}
                 continue ;
               fi
             ;;
            esac
            _NAME=$_N
	    #Finding the index from ddb or decided i from loop
            if [ -z "$_exist_ddb" ] ; then
              _INDEX=$i
            else
              message "Getting the index from the existing DDB entry"
              _INDEX=mdb-get-index-with-hostname($ENI_HOSTNAME)
	      #bug:55948
	      if [ -z "$_INDEX" ] ; then
                message "Node index wasnt retrieved with ENI_hostname. Using MARKLOGIC_HOSTNAME for DDB search"
                _INDEX=mdb-get-index-with-hostname($MARKLOGIC_HOSTNAME)
              fi
              message "Node index retrieved from DDB entry:  $_INDEX"
              #bug:55948
            fi
            break
         fi
       done
      fi
      if is-node-pattern "$_NAME" ; then
           error "Cannot find a name for $_NAME - exiting"
      fi
    else
      message "Checking if current node is in use: $MDB_NAME $_NAME"
  
       attributes=mdb-get-attributes-for-node( "$_NAME" )
       _instance=mdb-get-attr-string( $attributes instance )
       if is-blank $_instance ; then
          message "Node $_NAME is not in use"
       else
         if [ "$_instance" != "$INSTANCE" ] ; then
           message "Node $_NAME is in use by $_instance my instances is $INSTANCE - checking if it is running"
           _state=instance-state($_instance)
           case $_state in
             running|stopped|pending|rebooting) message "Instance $_instance already running  - cannot startup. state: $_state";
                    exit 1 ;
                   ;;
              *) message "Instance $_instance is not running - taking over"
  
                _DATE=mdb-get-attr-datetime( $attributes create-date)
                if [ <[ exists( $_DATE ) and $_DATE gt  ( fn:current-dateTime() - xs:dayTimeDuration("PT2M") ) ]> ] ; then
                     message "Node record created too recently, skipping: state: $_state date: $_DATE"
                     error "failed taking on node name:$_NAME. previous running instance $_instance failed too recently... aborting."
                  fi
                 if ! mdb-update-if-equals "$_NAME" instance "$_instance"  instance "$INSTANCE" \
                    create-date <[ fn:current-dateTime() ]>  zone $_ZONE  >{r} ; then
                    error "failed taking on node name:$_NAME ... aborting" {$r}
              fi
             ;;
         esac
       fi
      fi
     fi
    if [ -z "$_INDEX" -o -z "$_NAME" ] ; then
       error "Failed to find a node for name: $MARKLOGIC_NODE_NAME ... aborting"
    fi
  fi
  
  # Resolved full name
  is-node-pattern "$_NAME" && error "Failed to find a node for name: $MARKLOGIC_NODE_NAME ... aborting"
  [ -z "$_NAME" ] && error "Failed to allocate a node for name: $MARKLOGIC_NODE_NAME ... aborting" 
  MDB_NODE_NAME="$_NAME"
  mdb-update index "$_INDEX" create-date <[ fn:current-dateTime() ]>   zone "$_ZONE" >/dev/null

  _MASTER=$MARKLOGIC_CLUSTER_MASTER
  [ "$_MASTER" = 1 -a "$_INDEX" -ne 1 ] && _MASTER=0
  
  [ -n "$MARKLOGIC_AWS_ROLE" ] && setvalue MARKLOGIC_AWS_ROLE $MARKLOGIC_AWS_ROLE
  setvalue MARKLOGIC_CLUSTER_NAME "$MARKLOGIC_CLUSTER_NAME"
  setvalue MDB_NAME "$MDB_NAME"
  setvalue MARKLOGIC_NODE_NAME $_NAME
  setvalue MDB_NODE_NAME $_NAME
  setvalue MARKLOGIC_INSTANCE $INSTANCE
  setvalue MARKLOGIC_NODE_INDEX $_INDEX
  setvalue MARKLOGIC_CLUSTER_MASTER $_MASTER
  [ -z "$MARKLOGIC_S3_DOMAIN" -a "$AWS_REGION" != "us-east-1" ] && setvalue MARKLOGIC_S3_DOMAIN "s3-${AWS_REGION}.amazonaws.com"
  
  _exclude=(MDB_NAME MARKLOGIC_CLUSTER_NAME MDB_NODE_NAME MARKLOGIC_INSTANCE \
     MARKLOGIC_ADMIN_PASSWORD MARKLOGIC_ZONE MARKLOGIC_NODE_INDEX MARKLOGIC_JVM_OPTS MARKLOGIC_CLUSTER_MASTER )
  set >{_vars}
  for v in <[ $_vars//variable[ starts-with(@name , "MARKLOGIC_" ) and not(@name = $_exclude) ]/@name/string()  ]> ; do
    setvalue "$v" $(printvar $v)
  done
  # If we get here then save the init state 
  setvalue _MLCMD_CONF_INIT 1
}  

## Run it
run-init-config

} (cport)>&(output) (output)>&(error)

exit 0
