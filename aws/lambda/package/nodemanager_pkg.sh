#!/bin/sh
[ -e ../node_manager.zip ] && rm ../node_manager.zip
[ -e ../version.txt ] && rm ../version.txt

echo `date` > ../version.txt

cd ..
zip node_manager.zip nodemanager.py utils.py version.txt

chmod 777 node_manager.zip
