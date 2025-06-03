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
ec2_resource = boto3.resource('ec2')

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

        if not eni_info.attachment:
            time.sleep(sleep_interval)
            retries += 1
            continue
        status = eni_info.attachment["Status"]
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

def eni_wait_for_detachment(eni_id):
    max_rety = 10
    retries = 0
    sleep_interval = 10
    eni_info = None
    while True and retries < max_rety:
        try:
            eni_info = ec2_resource.NetworkInterface(id=eni_id)
            log.info("ENI Detachment status %s " % eni_info.status)
        except ClientError as e:
            reason = "Failed to get network interface by id %s" % eni_id
            log.exception(reason)
            time.sleep(sleep_interval)
            retries += 1
            continue

        status = eni_info.status
        if status == "available":
            time.sleep(sleep_interval)
            break
        elif status == "in-use":
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
            "Waiting for network interface %s detachment timed out" % eni_id
        )

def eni_wait_to_detach_attachment(eni_id):
    max_rety = 5
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

        status = eni_info.status
        if not eni_info.attachment and status == "available":
            break
        elif eni_info.attachment and status == "available":
            time.sleep(sleep_interval)
            retries += 1
            continue
        elif status == "in-use":
            break
    else:
        log.warning(
            "Waiting for network interface %s to detach attachment time out" % eni_id
        )
    return status


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
                log.info("ENI response %s" % eni_info)
                eni_id = eni_info["NetworkInterfaceId"]
                eni_status = eni_info["Status"]
                if "Attachment" in eni_info and eni_status != "available":
                    attached_instance_id = eni_info["Attachment"]["InstanceId"]
                    eni_attach_id = eni_info["Attachment"]["AttachmentId"]
                    log.info("Actual Instance and ENI Status and ENI Attach ID %s %s %s " % (
                    attached_instance_id, eni_status, eni_attach_id))

                    try:
                        attached_instance_response = ec2_client.describe_instances(InstanceIds=[attached_instance_id])
                    except botocore.exceptions.ClientError as e:
                        reason = "Failed to describe instance %s" % instance_id
                        log.exception(reason)

                    # Check if status is other than available and then check if actual instance is in shutting down or terminated status
                    if (attached_instance_response['Reservations'][0]['Instances'][0]['State']['Name']
                            in ["shutting-down", "terminated"]):
                        log.info("Attached Instance Response %s " % attached_instance_response)
                        log.info("Manually detaching the ENI %s " % eni_id)
                        # Logic to detach the ENI from the actual instance in shutting down or terminated status
                        try:
                            detach_response = ec2_client.detach_network_interface(
                            AttachmentId=eni_attach_id,
                        )
                        except botocore.exceptions.ClientError as e:
                            reason = "Error detaching network interface %s" % eni_id
                            log.exception(reason)
                        
                        eni_wait_for_detachment(eni_id)
                        eni_status = eni_wait_to_detach_attachment(eni_id)
                        log.info("ENI status check after detachment and detach attachment %s" % eni_status)

                    else:
                        continue
                # Reason to have this logic is sometimes though ENI status is AVAILABLE still attachment status exists and shows detached
                # When we try to attach the ENI it throws error saying ENI is already attached to an instance. Added sleep to give time to complete the detachment
                elif "Attachment" in eni_info and eni_status == "available":
                    if eni_info["Attachment"]["Status"] == "detached":
                        eni_wait_to_detach_attachment(eni_id)


                if eni_status != "available":
                    continue
                

                try:
                    attachment = ec2_client.attach_network_interface(
                        NetworkInterfaceId=eni_id,
                        InstanceId=instance_id,
                        DeviceIndex=1
                    )
                    log.info("Attaching ENI %s to instance %s" % (eni_id, instance_id))
                except botocore.exceptions.ClientError as e:
                    reason = "Error attaching network interface %s" % eni_id
                    log.exception(reason)
                    time.sleep(5)
                    continue
                eni_wait_for_attachment(eni_id)
                break
            else:
                continue
            break
    else:
        log.warning("Tags for stack name or stack id not found")