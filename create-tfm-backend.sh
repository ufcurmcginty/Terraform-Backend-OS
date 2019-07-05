#!/bin/bash

# Script adapted from the base of https://docs.microsoft.com/en-us/azure/terraform/terraform-backend.
# We cannot create this storage account and blob container using Terraform itself since
# we are creating the remote state storage for Terraform and Terraform needs this storage in terraform init phase.

if [ $# -ne 4 ]
then
  echo "Usage: ./create-azure-storage-account.sh <location/region(eg. eastus)> <resource-group-name> <storage-account-name> <container-name> <key-vault-name>"
  echo "NOTE: Use the following azure cli commands to check the right account and to login to az first:"
  echo "  az account list --output table                    => Check which Azure accounts you have."
  echo "  az account set -s \"<your-azure-account-name>\"     => Set the right azure account."
  echo "  az login                                          => Login to azure cli."
  exit 1
fi


LOCATION=$1
RESOURCE_GROUP_NAME=$2
STORAGE_ACCOUNT_NAME=$3
CONTAINER_NAME=$4
KEY_VAULT_NAME=$5

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query [0].value -o tsv)

# Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY

# Create key vault
az keyvault create --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP_NAME --location $LOCATION

# Create secret
az keyvault secret set --vault-name $KEY_VAULT_NAME --name “terraform-backend-key” --value $ACCOUNT_KEY

# Get secret value
#SECRET_VALUE=$(az keyvault secret show --name terraform-backend-key --vault-name $KEY_VAULT_NAME --query value -o tsv)

# Export the environment variable “ARM_ACCESS_KEY”, to be able to initialise terraform with the storage account backend
export ARM_ACCESS_KEY=$(az keyvault secret show --name terraform-backend-key --vault-name $KEY_VAULT_NAME --query value -o tsv)

# Get tfstate name
TFSTATE_NAME=${RESOURCE_GROUP_NAME%??}

# Initialise Terraform with the storage account as backend to store “$TFSTATE.tfstate” in the container “$CONTAINER_NAME” 
terraform init -backend-config=”storage_account_name=$STORAGE_ACCOUNT_NAME -backend-config=”container_name=$CONTAINER_NAME” -backend-config=”key=$TFSTATE_NAME.tfstate”

#
# Show output
echo "Storage_account_name: $STORAGE_ACCOUNT_NAME"
echo "Container_name: $CONTAINER_NAME"
echo "Access_key: $ACCOUNT_KEY"
echo "Key_vault_name: $KEY_VAULT_NAME"
echo "Secret_name: terraform-backend-key"
echo "Secret_value(ARM_access_key): $ARM_ACCESS_KEY"
echo "TFState file name: $TFSTATE_NAME"
echo "__________________________________________________________"

# Initialise Terraform with the storage account as backend to store “_.tfstate” in the container “tfsate” created in the first step above
echo "Initializing Terraform..."
terraform init -backend-config=”storage_account_name=$STORAGE_ACCOUNT_NAME” -backend-config=”container_name=$CONTAINER_NAME” -backend-config=”key=$TFSTATE_NAME.tfstate”

# Create the terraform service principal and the provider.tf file
# Prompts to choose either a populated or empty provider.tf azurerm provider block
# Exports the environment variables if you selected an empty block (and display the commands)
# Display the az login command to log in as the service principal
echo "___________________________________________________________"

# Export variables used in create-tfm-sp.sh, export_tf_vars, create-aad-client-app.sh
export KEY_VAULT_NAME="$KEY_VAULT_NAME"

echo "Creating Terraform Service Principal..."
sh supplemental/create-tfm-sp.sh