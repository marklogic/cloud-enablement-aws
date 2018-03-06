import boto3
import logging
import hashlib
from botocore.exceptions import ClientError
import cfn_resource
import time

log = logging.getLogger()
log.setLevel(logging.INFO)

# global variables
handler = cfn_resource.Resource()
ec2_client = boto3.client('ec2')
ec2_resource = boto3.resource('ec2')

def create_eni(subnet_id, tag):
    """
    Create ENI and populate the description with the tag content.
    This is a temporarily work around because of AWS SDK bug.
    :param subnet_id:
    :param tag:
    :return:
    """
    # TODO remove tag
    log.info("Creating ENI with tag %s" % tag)
    eni_id = None
    try:
        eni = ec2_client.create_network_interface(
            Groups=[],
            SubnetId=subnet_id,
            Description=tag
        )
        eni_id = eni['NetworkInterface']['NetworkInterfaceId']
        log.info("Successfully created Network Interface %s" % eni_id)
    except ClientError as e:
        log.error(
            "Error creating network interface: {}".
            format(e.response['Error']['Code'])
        )
    return eni_id

def delete_eni(eni_id):
    log.info("Deleting ENI %s" % eni_id)
    try:
        ec2_client.delete_network_interface(
            NetworkInterfaceId=eni_id
        )
    except ClientError as e:
        log.error(
            "Error deleting network interface: {}".
             format(e.response['Error']['Code'])
        )

def detach_eni(attachment_id):
    try:
        response = ec2_client.detach_network_interface(
            AttachmentId=attachment_id,
            Force=True
        )
    except ClientError as e:
        log.error("Error detaching network interface: %s" % e.response['Error']['Code'])

def eni_assgin_tag(eni_id, tag):
    # AWS SDK bug #1450
    # https://github.com/boto/boto3/issues/1450
    # log.info(eni_id)
    # log.info(type(eni_id))
    # eni = ec2_resource.NetworkInterface(id=eni_id)
    # tag = eni.create_tags(
    #     Tags=[
    #         {
    #             'Key': 'cluster-eni-id',
    #             'Value': tag
    #         }
    #     ]
    # )
    pass

def get_physical_resource_id(request_id):
    return hashlib.md5(request_id.encode()).hexdigest()

def get_network_interface_by_id(eni_id):
    """
    Use describe network interfaces function instead of ec2_resource.NetworkInterface
    AWS SDK bug #1450
    :param eni_id:
    :return:
    """
    response = ec2_client.describe_network_interfaces(
        Filters=[{
            "Name": "network-interface-id",
            "Values": [eni_id]
        }]
    )
    if len(response["NetworkInterfaces"]) == 1:
        return response["NetworkInterfaces"][0]
    else:
        log.error("Get network interface by id %s failed: %s" % (eni_id, str(response)))

@handler.create
def on_create(event, context):
    log.info("Handle resource create event")
    # get parameters passed in
    props = event["ResourceProperties"]
    stack_id = event["StackId"]
    nodes_per_zone = int(props["NodesPerZone"])
    zone_count = int(props["NumberOfZones"])
    parent_stack_name = props["ParentStackName"]
    parent_stack_id = props["ParentStackId"]
    subnets = props["Subnets"]
    log.info("Event: %s" % str(event))

    # prepare ENI meta information
    id_hash = hashlib.md5(parent_stack_id.encode()).hexdigest()
    eni_tag_prefix = parent_stack_name + "-" + id_hash + "_"

    # craete ENIs
    for i in range(0,zone_count):
        for j in range(0,nodes_per_zone):
            eni_idx = i * nodes_per_zone + j
            tag = eni_tag_prefix + str(eni_idx)
            eni_id = create_eni(subnets[i], tag)
            # TODO AWS SDK bug #1450
            # eni_assgin_tag(eni_id=eni_id, tag=tag)

    return {
       "Status" : "SUCCESS",
       "RequestId" : event["RequestId"],
       "LogicalResourceId" : event["LogicalResourceId"],
       "StackId" : stack_id,
       "PhysicalResourceId" : get_physical_resource_id(event["RequestId"])
    }

@handler.update
def on_update(event, context):
    # TODO based on the new ENI count, adding or removing ENIs
    pass

@handler.delete
def on_delete(event, context):
    log.info("Handle resource delete event")
    # get parameters passed in
    props = event["ResourceProperties"]
    stack_id = event["StackId"]
    nodes_per_zone = int(props["NodesPerZone"])
    zone_count = int(props["NumberOfZones"])
    parent_stack_name = props["ParentStackName"]
    parent_stack_id = props["ParentStackId"]
    log.info("Event: %s" % str(event))

    # prepare ENI meta information
    id_hash = hashlib.md5(parent_stack_id.encode()).hexdigest()
    eni_tag_prefix = parent_stack_name + "-" + id_hash + "_"

    # delete ENIs
    for i in range(0,zone_count):
        for j in range(0,nodes_per_zone):
            eni_idx = i * nodes_per_zone + j
            tag = eni_tag_prefix + str(eni_idx)
            log.info("Query EC2 for ENI with tag %s" % tag)
            # query
            response = ec2_client.describe_network_interfaces(
                # TODO AWS SDK bug #1450
                # Filters=[{
                #     "Name": "tag:cluster-eni-id",
                #     "Values": [tag]
                # }]
                Filters=[{
                    "Name": "description",
                    "Values": [tag]
                }]
            )
            for eni_info in response["NetworkInterfaces"]:
                eni_id = eni_info["NetworkInterfaceId"]
                log.info("Found network interface %s " % eni_id)
                # detach
                max_retry = 10
                retries = 0
                curr = eni_info
                while curr["Status"] != "available" and retries < max_retry:
                    status = curr["Status"]
                    if status == "in-use":
                        log.info("Network interface %s is in use, detaching it" % eni_id)
                        attachment_id = curr["Attachment"]["AttachmentId"]
                        detach_eni(attachment_id)
                        curr = get_network_interface_by_id(eni_id) # refresh eni info
                    elif status == "detaching" or status == "attaching":
                        log.info("Network interface %s is %s, waiting for completion" % (eni_id, status))
                        time.sleep(5)
                        retries += 1
                        curr = get_network_interface_by_id(eni_id)  # refresh eni info
                    else:
                        log.error(
                            "Network interface %s unexpected  status: %s" %
                            (eni_id, status)
                        )
                if curr["Status"] != "available":
                    log.error("Failed to delete network interface %s: unable to detach")
                    continue
                # delete
                delete_eni(eni_id)

    return {
        "Status": "SUCCESS",
        "RequestId": event["RequestId"],
        "LogicalResourceId": event["LogicalResourceId"],
        "StackId": stack_id,
        "PhysicalResourceId": get_physical_resource_id(event["RequestId"])
    }
