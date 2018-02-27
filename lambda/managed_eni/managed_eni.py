import boto3
import logging
import hashlib
from botocore.exceptions import ClientError
import cfn_resource

log = logging.getLogger()
log.setLevel(logging.DEBUG)

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
    eni_id = None
    try:
        eni = ec2_client.create_network_interface(
            Groups=[],
            SubnetId=subnet_id,
            Description=tag
        )
        eni_id = eni['NetworkInterface']['NetworkInterfaceId']
    except ClientError as e:
        log.error(
            "Error creating network interface: {}".
            format(e.response['Error']['Code'])
        )
    return eni_id

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

@handler.create
def on_create(event, context):
    # get parameters passed in
    props = event["ResourceProperties"]
    stack_id = event["StackId"]
    nodes_per_zone = int(props["NodesPerZone"])
    zone_count = int(props["NumberOfZones"])
    stack_name = props["StackName"]
    subnets = props["Subnets"]

    # prepare ENI meta information
    id_hash = hashlib.md5(stack_id.encode()).hexdigest()
    eni_tag_prefix = stack_name + "-" + id_hash + "_"

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
    # get parameters passed in
    props = event["ResourceProperties"]
    stack_id = event["StackId"]
    nodes_per_zone = int(props["NodesPerZone"])
    zone_count = int(props["NumberOfZones"])
    stack_name = props["StackName"]
    subnets = props["Subnets"]

    # prepare ENI meta information
    id_hash = hashlib.md5(stack_id.encode()).hexdigest()
    eni_tag_prefix = stack_name + "-" + id_hash + "_"

    # delete ENIs
    for i in range(0,zone_count):
        for j in range(0,nodes_per_zone):
            eni_idx = i * nodes_per_zone + j
            tag = eni_tag_prefix + str(eni_idx)
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
