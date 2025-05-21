#!/bin/sh
# Copyright (c) 2020 MarkLogic Corporation 
export MARKLOGIC_INSTALL_DIR=/opt/MarkLogic
exec $MARKLOGIC_INSTALL_DIR/mlcmd/bin/mlcmd "$@"
