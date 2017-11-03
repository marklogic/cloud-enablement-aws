# MarkLogic Solution Template on Azure

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmarklogic%2Fcloud-enablement%2Fmaster%2Fazure%2FsolutionTemplate.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/marklogic/cloud-enablement/master/azure/solutionTemplate.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

This Solution Template deploys MarkLogic clusters on Azure with Availability Set, Virtual Networks, Load Balancers, Managed Disks and other cloud resources. Advanced features such as MarkLogic HA will be configured for the cluster.

The Solution Template is a sample deployment for MarkLogic Clusters on Azure. Users are encouraged to customize the template to fit the needs in different environment.

## Getting Started

* To deploy from Azure Web Portal, go to [here]()
* To deploy from this repository, click the `Deploy to Azure` button under the title.
* To deploy using Azure CLI (or other APIs), clone this repository and pass the path to Azure CLI.

## Reference Architecture

The template exposes a set of parameters for users to configure the cluster. Depends on the values of parameters, users can choose to provision one node or three nodes clusters with Availability Set, Virtual Network, Load Balancer, Network Security Group and Virtual Machines.

The virtual machines provisioned by the template will each be initialized as a MarkLogic node and join together as a cluster. Advanced features including MarkLogic local-disk failover will be optionally configured on the cluster. The following image shows a typical architecture of the cluster on Azure.

![](doc/typical_architecture_of_azure_cluster.png)

The Solution Template consists of a mainTemplate, createUiDefinition, several sub-templates, and shell sripts for configuring MarkLogic cluster. The mainTemplate is the main entrance of the template. It links and invokes sub-templates as needed. The createUiDefinition is used to define Azure Marketplace interface, if you are deploying from this repository or using Azure CLI, createUiDefinition is unrelated. 

## Documentation

- [MarkLogic on Azure](https://developer.marklogic.com/products/cloud/azure)  
- [Deploying MarkLogic on Azure Using the Solution Template](http://pubs.marklogic.com:8011/guide/azure/Deploying)
