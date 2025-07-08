# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# ec2-get-meta [property]
# Get EC2 metadata 
metaurl=http://169.254.169.254/latest/meta-data
# http -connectTimeout 10 -get $metaurl/$1
TOKEN=$(http -connectTimeout 10 -H X-aws-ec2-metadata-token-ttl-seconds=21600 -put http://169.254.169.254/latest/api/token)
http -connectTimeout 10 -H X-aws-ec2-metadata-token=$TOKEN -get $metaurl/$1

