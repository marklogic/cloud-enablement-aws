#!/bin/sh
[ -e ../node_manager.zip ] && rm ../node_manager.zip
[ -e ../version.txt ] && rm ../version.txt

#get the last modified time of the files
LAST_MOD_TIME_UNIX=0
LAST_MOD_TIME=0
for f in `find .. -type f`; do
    TMP=`date -r $f +%s`
    if [[ $TMP -gt $LAST_MOD_TIME_UNIX ]]; then
        LAST_MOD_TIME_UNIX=$TMP
        LAST_MOD_TIME=`date -r $f`
    fi
done
echo $LAST_MOD_TIME > ../version.txt

cd ..
zip node_manager.zip nodemanager.py utils.py version.txt

chmod 777 node_manager.zip
