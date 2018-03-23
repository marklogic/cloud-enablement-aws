#!/bin/sh
rm ../node_manager.zip

cd ..
zip node_manager.zip nodemanager.py utils.py

chmod 777 node_manager.zip
