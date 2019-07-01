# Terraform-Backend-OS
Non-terraform scripts to create backend for open source Terraform running in a container in Azure.
Backend consists of an Azure storage account, key vault, secrets, container, and Azure AD integration.

# Create a Storage Account to manage terraform state for different clusters
Execute **create-tfm-backend.sh** while specifying:
### Location
* ex: eastus
### Resource group
* The resource group will be created with the name specified in the region specified
* ex: testuseatfmrg
* tfm = terraform
### Storage Account
* This will be where the tfstate and terraform config files will be stored
* This and every subsequent azure object will be created in the same resource group specified.
* ex: testuseatfmstac
### Container Name
* Container that manages the storage account
* ex: testuseatfmtfstate
### Key Vault Name
* Key Vault that will sotre all terraform related secrets
* A secret named **"terraform-backend-key"*** will also be created
  * This will allow terraform to access the storage account
* ex: testuseatfmkv
## Example: 
source **create-tfm-backend.sh** eastus testuseatfmrg testuseatfmstac testuseatfmtfstate testuseatfmkv

### Initialise terraform for AKS deployment
* This step will intialize Terraform with the storage account as backend to store the tfstate file in the container created in the first step above
* The tfstate will get its name from the resource group - the "rg"
* ex: if "testuseatfmrg", then "testuseatfm"

# Create a custom terraform service principal with least privilege to perform the AKS deployment
