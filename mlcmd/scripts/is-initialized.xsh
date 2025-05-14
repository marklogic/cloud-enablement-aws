# Wait for server to startup then determine if it is initialized
# Copyright (c) 2020 MarkLogic Corporation 
# is-initialized
. init
assert-managed

_state=mdb-node-state()
[ "$_state" = "initialized" ] && exit 0

while true ; do 
  try {
    sleep 1 
    rest-request localhost /admin/v1/timestamp 8001 >{r} 2>/dev/null
  } 
  catch X {
     message "Error contacting server - retry " {$X}
     continue 
  }
  RET=$?
  if [ $RET = 401 ] ; then  
     message "Server is initialized with authorization"
     exit 0
  elif [ $RET != 200 ] ; then 
    error "Failed checking server : $RET " {$r}
  else
    exit 1 # Not initialized
  fi
done

exit 0
