# wait for the timestamp to change on the server
# Copyright (c) 2020 MarkLogic Corporation 
# wait-for-startup [-secure] hostname [timestamp]
. init
_opts=$<(xgetopts -o "host:,ts:,retries:,secure" -a -noargs --  "$@")
shift $?
[ $# -ne 0 ] && error "$0: Invalid option: $*" xlocation()


UP=""
hasopt $_opts secure && UP=$CURL_AUTH
HOST=getopt($_opts host localhost)
TS=getopt($_opts ts dummy)
RETRY=getopt($_opts retries 100000000)
RETRY=<[ xs:int($RETRY) ]>

OTS=$TS
NTS=$TS
[ -n "$UP" ] && _AUTH="with http authentication for admin user $MARKLOGIC_ADMIN_USERNAME"
message "Waiting for host $HOST to startup: TS: $TS HOST: $HOST RETRY: $RETRY"  $_AUTH

while [ "$OTS" = "$NTS" ] ; do
  RETRY=<[ $RETRY - 1 ]> 
  if [ $RETRY -lt 0 ] ; then
    message "Failed to wait for host to startup $HOST" xlocation()
    exit 1 
  fi
  message "Sleeping to retry wait-for-startup:  RETRY: $RETRY"
  sleep-random 5 10 xlocation()
  rest-request $HOST /admin/v1/timestamp 8001 $UP >{check}
  RET=$?
  if [ $RET != 200 ] ; then 
    message "Failed checking server : $RET" {$check}
    continue ;
  fi 
  NTS=$check
done
message "Success contacting host $HOST"
exit 0

