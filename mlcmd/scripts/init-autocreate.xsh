# Copyright (c) 2020 MarkLogic Corporation 
#
# Auto create initial admin user
#

. init
assert-autocreate


#
# see if server is already initialized
#
if [ -s "$INIT_STATUS_FILE" ] ; then
   if [ -n "$MARKLOGIC_DATA_DIR" -a -s "$MARKLOGIC_DATA_DIR/groups.xml" ] ; then
   	message "Existing  MarkLogic installation detected at $MARKLOGIC_DATA_DIR." 
        exit 0
   fi
   message "Previous initialization detected." $(<$INIT_STATUS_FILE)
   message "Remove file $INIT_STATUS_FILE to retry initialuser creation"
   exit 0
fi




MARKLOGIC_ADMIN_PASSWORD=$(ec2-get-meta "$MARKLOGIC_ADMIN_AUTOCREATE") 
[ -n "MARKLOGIC_ADMIN_PASSWORD" ] || error "Failed to get metadata $MARKLOGIC_ADMIN_AUTOCREATE" xlocation() 

message "Creating initial user: $MARKLOGIC_ADMIN_USERNAME using metadata $MARKLOGIC_ADMIN_AUTOCREATE" xlocation()
if ! init-license-key -retries 30 ; then
    error "Initialization of license key failed - cannot proceed" xlocation()
fi 
          
message "Initialization of license key successful.  Initializing security database." xlocation()

# This can take a while -- 
_RETRY=<[ 10 ]>
while ! init-security -retries 10 ; do 
    _RETRY=<[ $_RETRY - 1 ]> 
   if [ $_RETRY -lt 0 ] ; then 
      error "Failed initializing host - cannot create initial user" xlocation()
   fi
   message "Retrying initializing host: retries left: $_RETRY" xlocation()
done


message "Suceeded initializing security database - wait for authenticated startup" xlocation()

if ! wait-for-startup -secure  ; then 
  error "Cannot contact localhost securly - aborting" xlocation()
fi

MSG="Successfully initialized server with initial user: $MARKLOGIC_ADMIN_USERNAME" 
DT=<[ fn:current-dateTime() ]>
echo "$DT: $MSG" >$INIT_STATUS_FILE  
message "$MSG" xlocation()
exit 0


