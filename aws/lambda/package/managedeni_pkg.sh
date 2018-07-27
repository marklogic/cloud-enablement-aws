#!/bin/sh

[ -e ../managed_eni.zip ] && rm ../managed_eni.zip
[ -e ../version.txt ] && rm ../version.txt

echo `date` > ../version.txt

cp custom_resource_base.zip ../managed_eni.zip

cd ..
zip -g managed_eni.zip managedeni.py
zip -g managed_eni.zip utils.py
zip -g managed_eni.zip version.txt

chmod 777 managed_eni.zip
