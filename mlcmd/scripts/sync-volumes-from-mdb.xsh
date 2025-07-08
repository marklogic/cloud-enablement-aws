#
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# sync-volumes -from [db | system]
#
. init
assert-managed

message "Syncing local volumes from mdb"
init-volumes-from-mdb 

