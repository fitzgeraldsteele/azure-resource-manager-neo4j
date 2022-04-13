# simple
This is an Azure Resource Manager (ARM) template that deploys Neo4j Enterprise on Azure.  It sets up Neo4j Graph Database, Graph Data Science and Bloom.  You can run it from the  CLI or using the [Azure Portal](https://portal.azure.com) with the buttons below:

[![Deploy to Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fneo4j-partners%2Fazure-resource-manager-neo4j%2Fmain%2Fsimple%2FmainTemplate.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fneo4j-partners%2Fazure-resource-manager-neo4j%2Fmain%2Fsimple%2FmainTemplate.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fneo4j-partners%2Fazure-resource-manager-neo4j%2Fmain%2Fsimple%2FmainTemplate.json)

The template provisions a virtual network, Virtual Machine Scale Sets (VMSS), Managed Disks with Premium Storage and Public IPs with a DNS record per node.  It also sets up a network security group.

## Environment Setup
You will need an Azure account.

First we need to install and configure the Azure CLI.  You can install the CLI by following the instructions [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).  Bascially all you need to do is run:

    brew update && brew install azure-cli
    az login

You can confirm the CLI is working properly by running:

    az group list

Then you'll want to clone this repo.  You can do that with the command:

    git clone https://github.com/neo4j-partners/azure-resource-manager-neo4j.git
    cd azure-resource-manager-neo4j
    cd simple

## Creating a Deployment
[deploy.sh](deploy.sh) is a helper script to create a deployment.  Take a look at it, the [mainTemplateParameters.json](mainTemplateParameters.json) and modify any parameters.  Then run it as:

    ./deploy.sh <RESOURCE_GROUP_NAME>

When complete the template prints the URLs to access Neo4j.

## Working with CA-signed Certificates

When working with non-public data, please carefully follow instructions in [Neo4j SSL Setup - 4.x.pdf](Neo4jSSLSetup-4.x.pdf) to configure a proper CA-signed certificate.  This document links to resources and videos which further clarify configuration.</i>

## Configuration notes

<ol> 
<li>Graph Data Science (GDS) currently runs on single node instances so even if you specify a license key and GDS version, it will not install on a multi-node cluster.</li>
<li>By default, the installer will choose the versions of APOC, Bloom, and GDS which are bundled on the server in <i>/labs</i> and <i>/plugins</i> directories specifically.  You can override these configurations explicitly.  For example, v4.4.5 ships with Bloom 2.1.0, which does not open in Neo Desktop.  So you would specify Bloom Version <i>2.1.1</i> in the configuration.</li>
<li>Installation takes around 4 minutes per machine.  You can check up on progress (and detect errors) with a command like

    sudo tail -100 /var/log/messages

</li>
<li>In a typical install, you will accept defaults and leave versions for GDS, Bloom, and APOC -- intentionally blank. 

    graphDataScienceVersion: None
    bloomVersion: None
    apocVersion: None

</li>
</ol>

## Deleting a Deployment
To delete your deployment you can either run the command below or use the GUI in the [Azure Portal](https://portal.azure.com).

    az group delete --yes --name <RESOURCE_GROUP_NAME>

## Debugging a Deployment
Each node runs a startup script that the waagent invokes.  To debug, you can SSH into the box and view the logs. They are in the directory `/var/lib/waagent/custom-script/download/1`
