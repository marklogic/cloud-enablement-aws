# Copyright (c) 2020 MarkLogic Corporation 
# ec2-get-region
# Returns the region of the current instance
zone=$(ec2-get-meta placement/availability-zone)
echo <[ substring( $zone , 0 , string-length($zone)  ) ]>
