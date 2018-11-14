# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.

import boto3
import logging
import hashlib
import json
from botocore.exceptions import ClientError
import cfn_resource
import time
from utils import get_network_interface_by_id
from utils import cfn_success_response
from utils import cfn_failure_response

log = logging.getLogger()
log.setLevel(logging.INFO)

# global variables
handler = cfn_resource.Resource()
ec2_client = boto3.client('ec2')
ec2_resource = boto3.resource('ec2')


def eni_wait_for_creation(eni_id):
    max_retry = 10
    retries = 0
    sleep_interval = 10
    while True and retries < max_retry:
        # resource is not ready yet, not visible to 'ec2_resource.NetworkInterface(id=eni_id)'
        eni_info = get_network_interface_by_id(eni_id)
        if eni_info:
            status = eni_info["Status"]
            if status == "available":
                return eni_info
            else:
                log.warning("Network interface %s in unexpected status: %s" % (eni_id, status))
                time.sleep(sleep_interval)
                retries += 1
        else:
            log.warning("Network interface %s not found" % eni_id)
            time.sleep(sleep_interval)
            retries += 1
    else:
        log.warning("Waiting for network interface %s creation timed out" % eni_id)

def eni_wait_for_detachment(eni_id):
    max_retry = 10
    retries = 0
    sleep_interval = 10
    while True and retries < max_retry:
        eni_info = ec2_resource.NetworkInterface(id=eni_id)
        if eni_info:
            if not eni_info.attachment:
                break

            status = eni_info.attachment["Status"]
            if status == "detached":
                break
            elif status == "attached" or status == "detaching":
                time.sleep(sleep_interval)
                retries += 1
                continue
            else:
                log.warning("Network interface %s in unexpected attachment status: %s" % (eni_id, status))
                time.sleep(sleep_interval)
                retries += 1
        else:
            log.warning("Network interface %s not found" % eni_id)
            time.sleep(sleep_interval)
            retries += 1
    else:
        log.warning("Waiting for network interface %s detachment timed out" % eni_id)

def eni_exist(subnet_id, security_group_id, tag):
    response = ec2_client.describe_network_interfaces(
        Filters=[
            {
                "Name": "tag:cluster-eni-id",
                "Values": [tag]
            },
            {
                "Name": "subnet-id",
                "Values": [subnet_id]
            },
            {
                "Name": "group-id",
                "Values": [security_group_id]
            }
        ]
    )
    if len(response["NetworkInterfaces"]) > 0:
        return response["NetworkInterfaces"][0]
    else:
        return None

def create_eni(subnet_id, security_group_id, tag):
    """
    Create ENI and populate the description with the tag content.
    This is a temporarily work around because of AWS SDK bug.
    :param subnet_id:
    :param tag:
    :return:
    """
    eni_info = eni_exist(subnet_id, security_group_id, tag)
    if eni_info:
        return eni_info
    try:
        eni = ec2_client.create_network_interface(
            Groups=[security_group_id],
            SubnetId=subnet_id,
        )
        eni_id = eni['NetworkInterface']['NetworkInterfaceId']
        log.info("Creating network interface %s in subnet %s with tag %s" % (
            eni_id,
            subnet_id,
            tag
        ))
    except ClientError as e:
        reason = "network interface %s in subnet %s with tag %s" % (
            eni_id,
            subnet_id,
            tag
        )
        log.exception(reason)
        time.sleep(5)
    log.info("Waiting for network interface %s creation finish" % eni_id)
    return eni_wait_for_creation(eni_id)

def detach_eni(eni_id, attachment_id):
    try:
        response = ec2_client.detach_network_interface(
            AttachmentId=attachment_id,
            Force=True
        )
        log.info("Detaching network interface %s" % eni_id)
    except ClientError as e:
        reason = "Failed to detach %s" % attachment_id
        log.exception(reason)
        time.sleep(5)
        return False
    log.info("Waiting for network interface %s detachment finish" % eni_id)
    eni_wait_for_detachment(eni_id)
    return True

def eni_assign_tag(eni_id, tag):
    eni = ec2_resource.NetworkInterface(id=eni_id)
    tag = eni.create_tags(
        Tags=[
            {
                'Key': 'cluster-eni-id',
                'Value': tag
            }
        ]
    )
    pass

@handler.create
def on_create(event, context):
    log.info("Handle resource create event %s" % json.dumps(event, indent=2))
    # get parameters passed in
    props = event["ResourceProperties"]
    nodes_per_zone = int(props["NodesPerZone"])
    zone_count = int(props["NumberOfZones"])
    parent_stack_name = props["ParentStackName"]
    parent_stack_id = props["ParentStackId"]
    subnets = props["Subnets"]
    security_group_id = props["SecurityGroup"]

    # prepare ENI meta information
    id_hash = hashlib.md5(parent_stack_id.encode()).hexdigest()
    eni_tag_prefix = parent_stack_name + "-" + id_hash + "_"

    dns = []
    # craete ENIs
    for i in range(0,zone_count):
        for j in range(0,nodes_per_zone):
            eni_idx = i * nodes_per_zone + j
            tag = eni_tag_prefix + str(eni_idx)
            eni_info = create_eni(subnets[i], security_group_id, tag)
            if not eni_info:
                reason = "Failed to create network interface with tag %s" % tag
                log.warning(reason)
                continue
            eni_id = eni_info["NetworkInterfaceId"]
            eni_dns = eni_info["PrivateDnsName"]
            eni_assign_tag(eni_id=eni_id, tag=tag)
            dns.append(eni_dns)

    return cfn_success_response(event,data={
        "Addresses": ",".join(dns)
    })

@handler.update
def on_update(event, context):
    log.info("Handle resource update event %s" % json.dumps(event, indent=2))
    # get parameters passed in
    props = event["ResourceProperties"]
    nodes_per_zone = int(props["NodesPerZone"])
    zone_count = int(props["NumberOfZones"])
    parent_stack_name = props["ParentStackName"]
    parent_stack_id = props["ParentStackId"]
    subnets = props["Subnets"]
    security_group_id = props["SecurityGroup"]
    # old properties
    old_props = event["OldResourceProperties"]
    old_nodes_per_zone = int(old_props["NodesPerZone"])
    old_zone_count = int(old_props["NumberOfZones"])

    # validate diff and handle special case
    if old_zone_count != zone_count:
        reason = "Updating number of zones is not supported"
        log.error(reason)
        return cfn_failure_response(event,reason)
    if old_nodes_per_zone > nodes_per_zone and nodes_per_zone != 0:
        reason = "Scaling down the number of nodes per zone by updating the stack is not recommended. " \
                 "Please manually remove unused network interface."
        log.warning(reason)
        return cfn_failure_response(event, reason)
    if nodes_per_zone == 0:
        log.info("Hibernating the cluster, retain network interfaces")
        nodes_per_zone = old_nodes_per_zone

    # prepare ENI meta information
    id_hash = hashlib.md5(parent_stack_id.encode()).hexdigest()
    eni_tag_prefix = parent_stack_name + "-" + id_hash + "_"

    dns = []
    eni_idx = 0
    for i in range(zone_count):
        for j in range(nodes_per_zone):
            tag = eni_tag_prefix + str(eni_idx)
            eni_idx += 1
            eni_info = create_eni(subnets[i], security_group_id, tag)
            if not eni_info:
                reason = "Failed to create network interface with tag %s" % tag
                log.warning(reason)
                continue
            eni_id = eni_info["NetworkInterfaceId"]
            eni_dns = eni_info["PrivateDnsName"]
            eni_assign_tag(eni_id=eni_id, tag=tag)
            dns.append(eni_dns)

    return cfn_success_response(event,reuse_physical_id=True,data={
        "Addresses": ",".join(dns)
    })

@handler.delete
def on_delete(event, context):
    log.info("Handle resource delete event %s " % json.dumps(event, indent=2))
    # get parameters passed in
    props = event["ResourceProperties"]
    nodes_per_zone = int(props["NodesPerZone"])
    zone_count = int(props["NumberOfZones"])
    parent_stack_name = props["ParentStackName"]
    parent_stack_id = props["ParentStackId"]

    # prepare ENI meta information
    id_hash = hashlib.md5(parent_stack_id.encode()).hexdigest()
    eni_tag_prefix = parent_stack_name + "-" + id_hash + "_"

    # delete ENIs
    eni_idx = 0
    while True:
        tag = eni_tag_prefix + str(eni_idx)
        log.info("Querying EC2 for ENI with tag %s" % tag)
        # query
        response = None
        try:
            response = ec2_client.describe_network_interfaces(
                Filters=[{
                    "Name": "tag:cluster-eni-id",
                    "Values": [tag]
                }]
            )
        except ClientError as e:
            reason = "Failed to describe network interface with tag %s" % tag
            log.exception(reason)
            time.sleep(5)
            eni_idx += 1
            continue

        if not response["NetworkInterfaces"]:
            break
        for eni_info in response["NetworkInterfaces"]:
            eni_id = eni_info["NetworkInterfaceId"]
            log.info("Found network interface %s " % eni_id)

            # detach
            if "Attachment" in eni_info and (
                        eni_info["Attachment"]["Status"] == "attached" or
                            eni_info["Attachment"]["Status"] == "attaching"
            ):
                attachment_id = eni_info["Attachment"]["AttachmentId"]
                if not detach_eni(eni_id, attachment_id):
                    reason = "Failed to detach network interface %s" % eni_id
                    log.error(reason)
            try:
                ec2_client.delete_network_interface(
                    NetworkInterfaceId=eni_id
                )
                log.info("Deleting network interface %s" % eni_id)
            except ClientError as e:
                reason = "Failed to delete network interface %s" % eni_id
                log.exception(reason)
                return cfn_failure_response(event, reason)
        eni_idx += 1
    return cfn_success_response(event)
