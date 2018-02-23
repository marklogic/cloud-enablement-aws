#!/bin/sh

# ref: https://goo.gl/nKULqB
# Lauch a MarkLogic AMI on AWS to prepare the lambda package
PEM_KEY=/space/workspace/aws/qa-builder.pem
HOST=ec2-54-160-90-78.compute-1.amazonaws.com
SRC_DIR=/space/workspace/cloud-enablement/aws/lambda/managed_eni.py
DEST_DIR=/tmp
PKG_NAME=managed_eni

# copy file to EC2 machine
scp -i $PEM_KEY -r $SRC_DIR ec2-user@$HOST:$DEST_DIR
# log in
ssh -i $PEM_KEY ec2-user@$HOST
# install system dependencies
sudo yum install -y gcc zlib zlib-devel openssl openssl-devel
cd /tmp
wget https://www.python.org/ftp/python/3.6.1/Python-3.6.1.tgz
tar -xzvf Python-3.6.1.tgz
cd Python-3.6.1 && ./configure && make
sudo make install
sudo /usr/local/bin/pip3 install virtualenv
# Choose the virtual environment that was installed via pip3
/usr/local/bin/virtualenv ~/ml_venv
source ~/ml_venv/bin/activate
# Install libraries in the virtual environment
pip install boto3
# Add the contents of lib and lib64 site-packages to .zip file
cd $VIRTUAL_ENV/lib/python3.6/site-packages
zip -r9 $DEST_DIR/$PKG_NAME.zip *
# Include lambda source code
cd $DEST_DIR
zip -g $PKG_NAME.zip *.py
