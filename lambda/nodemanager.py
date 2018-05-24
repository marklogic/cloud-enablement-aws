# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.

import boto3
import botocore
import logging
import hashlib
import json
import time
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

# global variables
ec2_client = boto3.client('ec2')
asg_client = boto3.client('autoscaling')

def eni_wait_for_attachment(eni_id):
    max_rety = 10
    retries = 0
    sleep_interval = 10
    eni_info = None
    while True and retries < max_rety:
        try:
            eni_info = ec2_resource.NetworkInterface(id=eni_id)
        except ClientError as e:
            reason = "Failed to get network interface by id %s" % eni_id
            log.exception(reason)
            time.sleep(sleep_interval)
            retries += 1
            continue

        status = eni_info["Attachment"]["Status"]
        if status == "attached":
            break
        elif status == "attaching":
            time.sleep(sleep_interval)
            retries += 1
            continue
        else:
            log.warning(
                "Network interface %s in unexpected status: %s" % (eni_id, status)
            )
            retries += 1
            continue
    else:
        log.warning(
            "Waiting for network interface %s attachment timed out" % eni_id
        )

def handler(event, context):
    msg_text = event["Records"][0]["Sns"]["Message"]
    msg = json.loads(msg_text)
    if "LifecycleTransition" in msg and \
                    msg["LifecycleTransition"] == "autoscaling:EC2_INSTANCE_LAUNCHING":
        log.info("Handle EC2_INSTANCE_LAUNCHING event %s" % (json.dumps(event, indent=2)))
        on_launch(msg)
        # continue with the life cycle event
        try:
            asg_client.complete_lifecycle_action(
                LifecycleHookName=msg['LifecycleHookName'],
                AutoScalingGroupName=msg['AutoScalingGroupName'],
                LifecycleActionToken=msg['LifecycleActionToken'],
                LifecycleActionResult='CONTINUE'
            )
        except botocore.exceptions.ClientError as e:
            reason = "Error completing life cycle hook for instance"
            log.exception(reason)
            time.sleep(5) # sleep for 5 seconds to allow exception info being sent to CloudWatch

def on_launch(msg):
    instance_id = msg["EC2InstanceId"]
    log.info("Launch event of instance %s" % instance_id)

    try:
        instance = ec2_client.describe_instances(InstanceIds=[instance_id])
    except botocore.exceptions.ClientError as e:
        reason = "Failed to describe instance %s" % instance_id
        log.exception(reason)
        time.sleep(5)
        return False

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
            log.info("Querying unattached ENI with tag %s" % tag)
            # query
            response = ec2_client.describe_network_interfaces(
                Filters=[
                    {
                        "Name": "tag:cluster-eni-id",
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
            # attach the available ENI
            for eni_info in response["NetworkInterfaces"]:
                eni_id = eni_info["NetworkInterfaceId"]
                try:
                    attachment = ec2_client.attach_network_interface(
                        NetworkInterfaceId=eni_id,
                        InstanceId=instance_id,
                        DeviceIndex=1
                    )
                    log.info("Attaching ENI %s to instance %s" % (eni_id, instance_id))
                    eni_wait_for_attachment(eni_id)
                except botocore.exceptions.ClientError as e:
                    reason = "Error attaching network interface %s" % eni_id
                    log.exception(reason)
                    time.sleep(5)
                    continue
                break
            else:
                continue
            break
    else:
        log.warning("Tags for stack name or stack id not found")