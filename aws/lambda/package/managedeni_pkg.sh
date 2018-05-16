#!/bin/sh
rm ../managed_eni.zip
cp custom_resource_base.zip managed_eni.zip

mv managed_eni.zip ../
cd ..
zip -g managed_eni.zip managedeni.py
zip -g managed_eni.zip utils.py

chmod 777 managed_eni.zip
