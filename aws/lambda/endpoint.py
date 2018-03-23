# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.

import boto3
import logging
import cfn_resource
from utils import get_physical_resource_id

log = logging.getLogger()
log.setLevel(logging.INFO)

# global variables
handler = cfn_resource.Resource()
ec2_client = boto3.client('ec2')
ec2_resource = boto3.resource('ec2')

@handler.create
def on_create(event, context):
    log.info("Handle resource create event")
    # get parameters passed in
    props = event["ResourceProperties"]
    stack_id = event["StackId"]
    vpc = props["Vpc"]
    service_name = props["ServiceName"]
    security_group = props["SecurityGroup"]
    subnets = props["Subnets"]
    log.info("Event: %s" % str(event))

    # create endpoint
    response = ec2_client.create_vpc_endpoint(
        VpcEndpointType='Interface',
        VpcId=vpc,
        ServiceName=service_name,
        SubnetIds=subnets,
        SecurityGroupIds=[security_group]
    )
    endpoint_id = response["VpcEndpoint"]["VpcEndpointId"]
    log.info(
        "Creating interface endpoint %s to service %s" % (
            endpoint_id, service_name
        )
    )
    return {
        "Status": "SUCCESS",
        "RequestId": event["RequestId"],
        "LogicalResourceId": event["LogicalResourceId"],
        "StackId": stack_id,
        "PhysicalResourceId": get_physical_resource_id(event["RequestId"])
    }

@handler.update
def on_update(event, context):
    pass

@handler.delete
def on_delete(event, context):
    pass