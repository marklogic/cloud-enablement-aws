#!/bin/sh mlcmd 
# Copyright (c) 2020 MarkLogic Corporation 
# mdb-init-node 
# Initialize the node record in the MetaDatabase
. init
assert-managed
message "Initializing node in mdb: $MDB_NODE_NAME"
required $0 MDB_NODE_NAME $MDB_NODE_NAME

MARKLOGIC_INSTANCE=$(ec2-get-meta instance-id)
HOST=$MARKLOGIC_HOSTNAME
MASTER=$MARKLOGIC_CLUSTER_MASTER

## Do not include 'node' as attribute explitly
## mdb-create-item name attr name attr ...
mdb-create-item  instance "$MARKLOGIC_INSTANCE" host "$HOST"  master "$MASTER" create-date <[ fn:current-dateTime() ]> >{r} || 
   error "Error putting attributes to domain $MDB_NAME" {$r}

if ! mdb-item-exists ; then 
    error "Failed to initialize record for $MDB_NODE_NAME" 
fi
exit 0 
