import boto3
import logging
import cfn_resource
import hashlib
from botocore.exceptions import ClientError

# TODO set logging
log = logging.getLogger()
log.setLevel(logging.DEBUG)

# global variables
handler = cfn_resource.Resource()
ec2_client = boto3.client('ec2')

def create_eni(subnet_id):
    eni_id = None
    try:
        eni = ec2_client.create_network_interface(
            Groups=[],
            SubnetId=subnet_id
        )
        eni_id = eni['NetworkInterface']['NetworkInterfaceId']
    except ClientError as e:
        log.error(
            "Error creating network interface: {}".
            format(e.response['Error']['Code'])
        )
    return eni_id

def eni_assgin_tag(eni_id, tag):
    eni = ec2_client.NetworkInterface(eni_id)
    tag = eni.create_tags(
        Tags=[
            {
                'Key': 'cluster-eni-id',
                'Value': tag
            }
        ]
    )

def get_physical_resource_id(request_id):
    return hashlib.md5(request_id.encode())

@handler.create
def on_create(event, context):
    # get parameters passed in
    props = event["ResourceProperties"]
    stack_id = event["StackId"]
    nodes_per_zone = props["NodesPerZone"]
    zone_count = props["NumberOfZones"]
    stack_name = props["StackName"]
    subnets = props["subnets"]

    # prepare ENI meta information
    id_hash = hashlib.md5(stack_id.encode())
    eni_tag_prefix = stack_name + "-" + id_hash + "_"

    # craete ENIs
    for i in zone_count:
        for j in nodes_per_zone:
            eni_idx = i * nodes_per_zone + j
            eni_id = create_eni(subnets[i])
            tag = eni_tag_prefix + str(eni_idx)
            eni_assgin_tag(eni_id=eni_id, tag=tag)

    return {
       "Status" : "SUCCESS",
       "RequestId" : event["RequestId"],
       "LogicalResourceId" : event["LogicalResourceId"],
       "StackId" : stack_id,
       "PhysicalResourceId" : get_physical_resource_id(event["RequestId"])
    }

@handler.update
def on_update(event, context):
    pass

@handler.delete
def on_delete(event, context):
    # get parameters passed in
    props = event["ResourceProperties"]
    stack_id = event["StackId"]
    nodes_per_zone = props["NodesPerZone"]
    zone_count = props["NumberOfZones"]
    stack_name = props["StackName"]
    subnets = props["subnets"]

    # prepare ENI meta information
    id_hash = hashlib.md5(stack_id.encode())
    eni_tag_prefix = stack_name + "-" + id_hash + "_"

    # delete ENIs
    for i in zone_count:
        for j in nodes_per_zone:
            eni_idx = i * nodes_per_zone + j
            eni_id = create_eni(subnets[i])
            tag = eni_tag_prefix + str(eni_idx)
            # query
            response = ec2_client.describe_network_interfaces(
                Filters=[{
                    "Name": "tag:cluster-eni-id",
                    "Values": [tag]
                }]
            )
            # delete
            for eni_info in response["NetworkInterfaces"]:
                eni_id = eni_info["NetworkInterfaceId"]
                ec2_client.delete_network_interface(
                    NetworkInterfaceId=eni_id
                )

    return {
        "Status": "SUCCESS",
        "RequestId": event["RequestId"],
        "LogicalResourceId": event["LogicalResourceId"],
        "StackId": stack_id,
        "PhysicalResourceId": get_physical_resource_id(event["RequestId"])
    }