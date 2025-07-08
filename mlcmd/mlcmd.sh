#!/bin/sh
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
export MARKLOGIC_INSTALL_DIR=/opt/MarkLogic
exec $MARKLOGIC_INSTALL_DIR/mlcmd/bin/mlcmd "$@"
