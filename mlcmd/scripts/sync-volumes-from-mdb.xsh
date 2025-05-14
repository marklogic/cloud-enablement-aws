#
# Copyright (c) 2020 MarkLogic Corporation 
# sync-volumes -from [db | system]
#
. init
assert-managed

message "Syncing local volumes from mdb"
init-volumes-from-mdb 

