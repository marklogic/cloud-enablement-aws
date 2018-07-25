#!/bin/sh

[ -e ../managed_eni.zip ] && rm ../managed_eni.zip
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

cp custom_resource_base.zip ../managed_eni.zip

cd ..
zip -g managed_eni.zip managedeni.py
zip -g managed_eni.zip utils.py
zip -g managed_eni.zip version.txt

chmod 777 managed_eni.zip
