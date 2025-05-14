# ec2-get-userdata
# Copyright (c) 2024 MarkLogic Corporation 
# metaurl=http://169.254.169.254/latest/user-data
# http -connectTimeout 10 -get $metaurl
metaurl=http://169.254.169.254/latest/user-data
TOKEN=$(http -connectTimeout 10 -H X-aws-ec2-metadata-token-ttl-seconds=21600 -put http://169.254.169.254/latest/api/token)
http -connectTimeout 10 -H X-aws-ec2-metadata-token=$TOKEN -get $metaurl
if [ $? = 200 ] ; then
  echo 
  exit 0
else
  exit 1
fi
