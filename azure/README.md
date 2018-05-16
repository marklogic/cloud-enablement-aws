# MarkLogic Solution Template on Azure

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmarklogic%2Fcloud-enablement%2Fmaster%2Fazure%2FmainTemplate.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/marklogic/cloud-enablement/master/azure/mainTemplate.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

This Solution Template can be used to deploy MarkLogic clusters on Azure. It is a sample deployment architecture. Users are encouraged to customize the template to fit their needs for different purposes.

## Getting Started

* To deploy from Azure Web Portal, navigate to [Azure Marketplace](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=marklogic&page=1) 
* To deploy from this repository, click the `Deploy to Azure` button under the title  
* To deploy using Azure CLI (or other tools), refer to the Microsoft Azure [article](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy-cli)
* To see the visualization of deployment structures, click the `Visualize` button under the title

## Reference Architecture

The Solution Template exposes a set of parameters enabling users to configure the MarkLogic cluster on Azure. Using the parameter values, users can choose to provision one node or three node clusters with Aazure features including Availability Set, Virtual Network, Load Balancer, Network Security Group, and Virtual Machines.

The virtual machines provisioned by the template will each be initialized as a MarkLogic node and joined together as a cluster. Advanced features including MarkLogic local-disk failover can be also configured on the cluster. The following image shows a typical architecture of the cluster on Azure.

![](doc/typical_architecture_of_azure_cluster.png)

The Solution Template consists of a mainTemplate, createUiDefinition, several sub-templates, and shell sripts for configuring MarkLogic cluster. The mainTemplate is the main entrance of the template. It links and invokes sub-templates as needed. The createUiDefinition is used to define Azure Marketplace interface. If you are deploying from this repository or using Azure CLI, createUiDefinition won't be used. 

## Documentation

- [MarkLogic Server on Azure Guide](http://docs.marklogic.com/guide/azure)
- [MarkLogic on Azure](https://developer.marklogic.com/products/cloud/azure)  
