# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.

import boto3
import logging
import time
import cfn_resource
from utils import get_physical_resource_id

log = logging.getLogger()
log.setLevel(logging.INFO)

# global variables
handler = cfn_resource.Resource()
ec2_client = boto3.client('ec2')
ec2_resource = boto3.resource('ec2')

def endpoint_wait_for_deletion(endpoint_id):
    max_retry = 10
    retries = 0
    while True and retries < max_retry:
        endpoint_info = ec2_client.describe_vpc_endpoints(
            Filters=[{
                "Name": "vpc-endpoint-id",
                "Values": [endpoint_id]
            }]
        )
        status = endpoint_info["VpcEndpoints"][0]["State"]
        if status == "deleted":
            break
        elif status == "deleting":
            time.sleep(5)
            retries += 1
        else:
            log.warning(
                "Endpoint %s in unexpected status: %s" % (endpoint_id, status)
            )
    else:
        log.warning(
            "Waiting for endpoint %s deletion failed" % endpoint_id
        )

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


@handler.delete
def on_delete(event, context):
    log.info("Handle resource delete event")
    # get parameters passed in
    props = event["ResourceProperties"]
    stack_id = event["StackId"]
    service_name = props["ServiceName"]
    log.info("Event: %s" % str(event))

    # find endpoint
    response = ec2_client.describe_vpc_endpoints(
        Filters=[{
            "Name": "service-name",
            "Values": [service_name]
        }]
    )
    if len(response["endpoint_id"]) <= 0:
        log.warning("No %s endpoint found" % service_name)
    else:
        endpoint_id = response["endpoint_id"][0]["VpcEndpointId"]
        response = ec2_client.delete_vpc_endpoints(
            VpcEndpointIds=[endpoint_id]
        )
        if "Unsuccessful" in response and len(response["Unsuccessful"]) > 0:
            log.error(
                "Failed to delete endpoint %s: %s" % (
                    endpoint_id,
                    response["Unsuccessful"][0]["Error"]["Message"]
                )
            )
        else:
            endpoint_wait_for_deletion(endpoint_id)
    return {
        "Status": "SUCCESS",
        "RequestId": event["RequestId"],
        "LogicalResourceId": event["LogicalResourceId"],
        "StackId": stack_id,
        "PhysicalResourceId": get_physical_resource_id(event["RequestId"])
    }
