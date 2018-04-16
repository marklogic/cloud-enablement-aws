# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.

import boto3
import logging
import time
import json
import cfn_resource
from utils import cfn_success_response
from utils import cfn_failure_response
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

# global variables
handler = cfn_resource.Resource()
ec2_client = boto3.client('ec2')
ec2_resource = boto3.resource('ec2')

def endpoint_wait_for_creation(endpoint_id):
    max_retry = 10
    retries = 0
    sleep_interval = 10
    while True and retries < max_retry:
        endpoint_info = None
        try:
            endpoint_info = ec2_client.describe_vpc_endpoints(
                Filters=[{
                    "Name": "vpc-endpoint-id",
                    "Values": [endpoint_id]
                }]
            )
        except ClientError as e:
            log.exception("describe vpc endpoint error")
            time.sleep(sleep_interval)
            retries += 1
            continue

        if len(endpoint_info["VpcEndpoints"]) == 0:
            time.sleep(sleep_interval)
            retries += 1
            continue

        status = endpoint_info["VpcEndpoints"][0]["State"]
        if status == "available":
            break
        elif status == "pending":
            time.sleep(sleep_interval)
            retries += 1
            continue
        else:
            log.warning(
                "Endpoint %s in unexpected status: %s" % (endpoint_id, status)
            )
            time.sleep(sleep_interval)
            retries += 1
            continue
    else:
        log.warning(
            "Waiting for endpoint %s creation timed out" % endpoint_id
        )

@handler.create
def on_create(event, context):
    log.info("Handle resource create event %s" % json.dumps(event, indent=2))
    # get parameters passed in
    props = event["ResourceProperties"]
    vpc = props["Vpc"]
    service_name = props["ServiceName"]
    security_group = props["SecurityGroup"]
    subnets = props["Subnets"]

    # create endpoint
    try:
        response = ec2_client.create_vpc_endpoint(
            VpcEndpointType='Interface',
            VpcId=vpc,
            ServiceName=service_name,
            SubnetIds=subnets,
            SecurityGroupIds=[security_group]
        )
    except ClientError as e:
        reason="Failed to create vpc endpoint for service %s" % service_name
        log.exception(reason)
        time.sleep(5) # sleep for 5 seconds to allow exception info being sent to CloudWatch
        return cfn_failure_response(event, reason)

    endpoint_id = response["VpcEndpoint"]["VpcEndpointId"]
    log.info(
        "Creating vpc endpoint %s for service %s" % (
            endpoint_id, service_name
        )
    )
    log.info("Waiting for vpc endpoint %s creation finish" % endpoint_id)
    endpoint_wait_for_creation(endpoint_id)

    return cfn_success_response(event)


@handler.delete
def on_delete(event, context):
    log.info("Handle resource delete event %s" % json.dumps(event, indent=2))
    # get parameters passed in
    props = event["ResourceProperties"]
    service_name = props["ServiceName"]
    vpc = props["Vpc"]

    # find endpoint
    response = None
    try:
        response = ec2_client.describe_vpc_endpoints(
            Filters=[
                {
                    "Name": "service-name",
                    "Values": [service_name]
                },
                {
                    "Name": "vpc-id",
                    "Values": [vpc]
                }
            ]
        )
    except ClientError as e:
        reason = "Failed to describe vpc endpoint for service %s" % service_name
        log.exception(reason)
        time.sleep(5) # sleep for 5 seconds to allow exception info being sent to CloudWatch
        return cfn_failure_response(event, reason)

    if len(response["VpcEndpoints"]) <= 0:
        log.info("No endpoint found for service %s" % service_name)
    else:
        endpoint_id = response["VpcEndpoints"][0]["VpcEndpointId"]
        try:
            response = ec2_client.delete_vpc_endpoints(
                VpcEndpointIds=[endpoint_id]
            )
            log.info("Deleting endpoint %s" % endpoint_id)
        except ClientError as e:
            reason = "Failed to delete vpc endpoint %s" % endpoint_id
            log.exception(reason)
            time.sleep(5)
            return cfn_failure_response(event, reason)

        if "Unsuccessful" in response and len(response["Unsuccessful"]) > 0:
            reason = "Failed to delete vpc endpoint %s: %s" % (
                endpoint_id,
                response["Unsuccessful"][0]["Error"]["Message"]
            )
            log.error(reason)
            time.sleep(5)
            return cfn_failure_response(event, reason)

    return cfn_success_response(event)
