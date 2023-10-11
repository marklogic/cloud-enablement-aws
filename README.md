# MarkLogic CloudFormation Template on AWS

The CloudFormation templates provide options to launch MarkLogic clusters with different settings. The parameterized templates will ask users to choose configurations prior to launch. With the chosen setting, the template will create resources by AWS service including but not limited to Elastic Compute Cloud, Elastic Block Storage, Virtual Private Cloud, DynamoDB, Simple Notification Service, CloudWatch, Lambda Functions, Elastic Load Balancer.

This repository contains master templates, sub-templates and other resources that are used by CloudFormation such as Lambda function source code. This is a quick start deployment architecture. Users are encouraged to customize the templates to fit their needs for different purpose.

For deploying MarkLogic on Azure, please visit [cloud-enablement-azure](https://github.com/marklogic/cloud-enablement-azure).

## Getting Started

| Template Type | Launch in US West 2 (Oregon) |
| -- | -- |
| MarkLogic in New VPC | [![Launch Stack](https://cdn.rawgit.com/buildkite/cloudformation-launch-stack-button-svg/master/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?region=us-west-2&stackName=mlClusterStack&templateURL=https://marklogic-db-template-releases.s3-us-west-2.amazonaws.com/11.0-latest/mlcluster-vpc.template) |
| MarkLogic in Existing VPC | [![Launch Stack](https://cdn.rawgit.com/buildkite/cloudformation-launch-stack-button-svg/master/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?region=us-west-2&stackName=mlClusterStack&templateURL=https://marklogic-db-template-releases.s3-us-west-2.amazonaws.com/11.0-latest/mlcluster.template) |

- To deploy from MarkLogic Website, go to [MarkLogic and Amazon Web Service](https://developer.marklogic.com/products/cloud/aws).
- To deploy from this GitHub repository, click on `Launch Stack` button above.
- To customize the templates, clone this repository and make modification. You can deploy the modifed templates from AWS Web Console or AWS CLI. Refer to [AWS Documentation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacks.html) for instructions.

## Reference Architecture

The CloudFormation templates provide options to launch clusters with different settings. The table below summarizes a few possible settings.

| Option | Allowed Values |
| -- | -- |
| VPC | New or Existing |
| License | Developer, BYOL, Essential Enterprise |
| Availablity Zone | 1 or 3 |
| Nodes per Zone | 1 to many |

The parameterized templates will ask users to choose configurations prior to launch. With the chosen setting, the template will create resources by AWS service including but not limited to Elastic Compute Cloud, Elastic Block Storage, Virtual Private Cloud, DynamoDB, Simple Notification Service, CloudWatch, Lambda Functions, Elastic Load Balancer. The following image shows a typical architecture of the cluster on AWS.

![](doc/typical_architecture_of_aws_cluster.png)

This directory contains master templates, sub-templates and other resources that are used by templates such as Lambda function source code.

## Documentation

- [MarkLogic Server on AWS Guide](http://docs.marklogic.com/guide/ec2)
- [MarkLogic on AWS](https://developer.marklogic.com/products/cloud/aws)  

## Additional Notes
### AWS Classic Load Balancer Removed from Single Zone Deployments:

Since AWS is retiring the Classic Load Balancer (CLB) as of August 15, 2022, the CLB has been removed for single-zone deployments in the MarkLogic CloudFormation templates. The URL in the outputs of the CloudFormation stack is now replaced with a private DNS name, which can be used to access the MarkLogic cluster.

### Python Upgrade for Lambda Functions in the MarkLogic CloudFormation Templates:

The lambda functions in MarkLogic CloudFormation templates used on AWS are now configured to use Python 3.9. AWS has scheduled the end of support for Python 3.6 by July 2022.

### Launch Templates and IMDSv2 support in the MarkLogic CloudFormation Templates:

Starting with MarkLogic 11.1.0, the MarkLogic CloudFormation Templates replaces the use of Launch Configurations with Launch Templates. This ensures that MarkLogic CFT users can make use of all of the Amazon EC2 Auto Scaling features now available in Launch Templates.

Additionally, MarkLogic 11.1.0 adds support for IMDSv2. The IMDSv2 option is set to "required" by default in the 11.1.0 and later CFTs. In order to use MarkLogic Server AMIs before 11.1.0 with the new templates, the templates need to be modified to set IMDSv2 to "optional" as IMDSv2 is not supported in earlier versions of the MarkLogic AMI.

## Support

The cloud-enablement-azre repository is maintained by MarkLogic Engineering and distributed under the [Apache 2.0 license](https://github.com/marklogic/cloud-enablement-aws/blob/master/LICENSE.TXT). Everyone is encouraged to file bug reports, feature requests, and pull requests through [GitHub](https://github.com/marklogic/cloud-enablement-aws/issues/new). Your input is important and will be carefully considered. However, we can’t promise a specific resolution or timeframe for any request. In addition, MarkLogic provides technical support for [releases](https://github.com/marklogic/cloud-enablement-aws/releases) of cloud-enablement-aws to licensed customers under the terms outlined in the [Support Handbook](http://www.marklogic.com/files/Mark_Logic_Support_Handbook.pdf). For more information or to sign up for support, visit [help.marklogic.com](http://help.marklogic.com).
