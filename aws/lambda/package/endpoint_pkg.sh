#!/bin/sh
rm ../endpoint.zip
cp custom_resource_base.zip endpoint.zip

mv endpoint.zip ../
cd ..
zip -g endpoint.zip endpoint.py
zip -g endpoint.zip utils.py

chmod 777 endpoint.zip
