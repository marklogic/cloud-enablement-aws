# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.

import boto3
import botocore
import logging
import hashlib
import json
import time
from botocore.exceptions import ClientError
from utils import get_network_interface_by_id

log = logging.getLogger()
log.setLevel(logging.INFO)

# global variables
ec2_client = boto3.client('ec2')
asg_client = boto3.client('autoscaling')

def wait_for_completion_attachment(eni_id):
    max_rety = 50
    retries = 0
    while True and retries < max_rety:
        eni_info = get_network_interface_by_id(eni_id)
        if eni_info["Attachment"]["Status"] == "attached":
            break
        elif eni_info["Attachment"]["Status"] == "attaching":
            time.sleep(1)
            retries += 1
        else:
            log.warning(
                "Network interface in unexpected status: %s" % eni_id
            )
    else:
        log.warning(
            "Waiting for network interface %s attachment failed" % eni_id
        )

def handler(event, context):
    log.info("Event: " + str(event))
    msg_text = event["Records"][0]["Sns"]["Message"]
    msg = json.loads(msg_text)
    if "LifecycleTransition" in msg and \
                    msg["LifecycleTransition"] == "autoscaling:EC2_INSTANCE_LAUNCHING":
        on_launch(msg)
        try:
            asg_client.complete_lifecycle_action(
                LifecycleHookName=msg['LifecycleHookName'],
                AutoScalingGroupName=msg['AutoScalingGroupName'],
                LifecycleActionToken=msg['LifecycleActionToken'],
                LifecycleActionResult='CONTINUE'
            )
        except botocore.exceptions.ClientError as e:
            log.error(
                "Error completing life cycle hook for instance: {}".format(e.response['Error']['Code'])
            )

def on_launch(msg):
    instance_id = msg["EC2InstanceId"]
    log.info("Handle launch event of instance %s" % instance_id)
    try:
        instance = ec2_client.describe_instances(InstanceIds=[instance_id])
    except botocore.exceptions.ClientError as e:
        log.warning(
            "Error describing the instance {}: {}".
                format(instance_id, e.response['Error']['Code'])
        )
        return

    # manage ENI
    subnet_id = instance['Reservations'][0]['Instances'][0]['SubnetId']
    tags = instance['Reservations'][0]['Instances'][0]['Tags']
    stack_name = None
    stack_id = None
    for tag in tags:
        if tag["Key"] == "marklogic:stack:name":
            stack_name = tag["Value"]
        if tag["Key"] == "marklogic:stack:id":
            stack_id = tag["Value"]
    if stack_name and stack_id:
        log.info("Subnet: %s, Stack Name: %s, Stack Id: %s" % (str(subnet_id), stack_name, stack_id))
        id_hash = hashlib.md5(stack_id.encode()).hexdigest()
        eni_tag_prefix = stack_name + "-" + id_hash + "_"

        for i in range(0,200):
            tag = eni_tag_prefix + str(i)
            log.info("Query unattached ENI with tag %s" % tag)
            # query
            response = ec2_client.describe_network_interfaces(
                # TODO AWS SDK bug #1450
                # Filters=[{
                #     "Name": "tag:cluster-eni-id",
                #     "Values": [tag]
                # }]
                Filters=[
                    {
                        "Name": "description",
                        "Values": [tag]
                    },
                    {
                        "Name": "status",
                        "Values": ["available"]
                    },
                    {
                        "Name": "subnet-id",
                        "Values": [subnet_id]
                    }
                ]
            )
            if len(response["NetworkInterfaces"]) == 0:
                log.info("No qualified ENI found")
                continue
            # attach the first available ENI
            for eni_info in response["NetworkInterfaces"]:
                eni_id = eni_info["NetworkInterfaceId"]
                try:
                    attachment = ec2_client.attach_network_interface(
                        NetworkInterfaceId=eni_id,
                        InstanceId=instance_id,
                        DeviceIndex=1
                    )
                    log.info("Attaching ENI %s to instance %s" % (eni_id, instance_id))
                    wait_for_completion_attachment(eni_id)
                except botocore.exceptions.ClientError as e:
                    log.error("Error attaching network interface: {}".format(e.response['Error']['Code']))
                break
            break
    else:
        log.warning("Tags for stack name or stack id not found!")