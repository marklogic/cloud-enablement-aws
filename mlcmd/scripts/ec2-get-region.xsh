# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# ec2-get-region
# Returns the region of the current instance
zone=$(ec2-get-meta placement/availability-zone)
echo <[ substring( $zone , 0 , string-length($zone)  ) ]>
