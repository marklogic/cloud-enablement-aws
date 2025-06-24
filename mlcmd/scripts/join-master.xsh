#
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# join-master
. init
assert-managed

if is-master ; then 
   message "Not a cluster joiner"
   exit 0
fi

# Get a list of potential hosts to join from simpledb ordered with master host first

while true ; do
   message "Getting list of potential hosts to contact"
   _hosts=get-joining-hosts()
   if [ <[ empty($_hosts) ]> ] ;  then
         message "No active hosts yet waiting to come online" ;
         sleep 20 ;
         continue ;
   fi 
   message "Attempting to join to the following hosts: $_hosts" 
   for _host in $_hosts ; do 
       message "Waiting for cluster host $_host" to be online 
       if ! wait-for-startup -secure -host $_host -retries 1 ; then 
         message "Cluster host $_host is not online - retry"
         sleep-random 5 10  xlocation()
         continue ;
       fi  
      
       message "Attempting to join cluster via host $_host"
       if  join-cluster $_host ; then 
        message "Successfully joined cluster"
        message "Waiting until local host responds to authenticated endpoint"
        sleep 5
        wait-for-startup -secure -host $MARKLOGIC_HOSTNAME -retries 10 || error "Error contacting localhost securely - aborting"
        break 2;
      fi
   done
   message "Cannot find any active hosts in cluster to join - waiting to come online"
   sleep 30
done
exit 0
