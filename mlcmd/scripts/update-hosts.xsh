#
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
. init

if [ -n "$MARKLOGIC_HOST_FILE" ] ; then 
   TMP=`mktemp`
   mdb-update-instance-state
   get-active-hosts > $TMP
   if ! [ -f $MARKLOGIC_HOST_FILE ] || ! xcmp -n $MARKLOGIC_HOST_FILE $TMP ; then
          cp -f $TMP $MARKLOGIC_HOST_FILE
   fi
   rm -f $TMP
fi
exit 0
