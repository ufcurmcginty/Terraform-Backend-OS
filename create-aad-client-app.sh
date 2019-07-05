#!/bin/bash
set -e

# Interactively set variables
if [ $# -ne 4 ]
then
  echo "Usage: sh create-aad-client-app.sh <azure ad client app name (ex: AKSAADClient01)> <azure ad client url (ex: http://aksaadclient01)>"
  echo "NOTE: Use the following azure cli commands to check the right account and to login to az first:"
  echo "  az account set -s \"<your-azure-account-name>\"     => Set the right azure account."
  echo "  az login                                          => Login to azure cli."
  exit 1
fi

RBAC_CLIENT_APP_NAME=$1
RBAC_CLIENT_APP_URL=$2


# load environment variables
export RBAC_AZURE_TENANT_ID="c0485409-6417-4a7f-bb35-d4ab8ba44e80"
export RBAC_CLIENT_APP_NAME
export RBAC_CLIENT_APP_URL

# export RBAC_SERVER_APP_ID="COMPLETE_AFTER_SERVER_APP_CREATION"
# export RBAC_SERVER_APP_OAUTH2PERMISSIONS_ID="COMPLETE_AFTER_SERVER_APP_CREATION"
# export RBAC_SERVER_APP_SECRET="COMPLETE_AFTER_SERVER_APP_CREATION"

export RBAC_SERVER_APP_ID
export RBAC_SERVER_APP_OAUTH2PERMISSIONS_ID
export RBAC_SERVER_APP_SECRET


# generate manifest for client application
cat > ./manifest-client.json << EOF
[
    {
      "resourceAppId": "${RBAC_SERVER_APP_ID}",
      "resourceAccess": [
        {
          "id": "${RBAC_SERVER_APP_OAUTH2PERMISSIONS_ID}",
          "type": "Scope"
        }
      ]
    }
]
EOF

# create client application
az ad app create --display-name ${RBAC_CLIENT_APP_NAME} \
    --native-app \
    --reply-urls "${RBAC_CLIENT_APP_URL}" \
    --homepage "${RBAC_CLIENT_APP_URL}" \
    --required-resource-accesses @manifest-client.json

RBAC_CLIENT_APP_ID=$(az ad app list --display-name ${RBAC_CLIENT_APP_NAME} --query [].appId -o tsv)

# create service principal for the client application
az ad sp create --id ${RBAC_CLIENT_APP_ID}

# remove manifest-client.json
rm ./manifest-client.json

# grant permissions to server application
RBAC_CLIENT_APP_RESOURCES_API_IDS=$(az ad app permission list --id $RBAC_CLIENT_APP_ID --query [].resourceAppId --out tsv | xargs echo)
for RESOURCE_API_ID in $RBAC_CLIENT_APP_RESOURCES_API_IDS;
do
  az ad app permission grant --api $RESOURCE_API_ID --id $RBAC_CLIENT_APP_ID
done

# Export variables to Azure Key Vault KEY_VAULT_NAME 
az keyvault secret set --vault-name $KEY_VAULT_NAME --name “TF_VAR_rbac_server_app_id” --value $RBAC_SERVER_APP_ID
az keyvault secret set --vault-name $KEY_VAULT_NAME --name “TF_VAR_rbac_server_app_secret” --value $RBAC_SERVER_APP_SECRET
az keyvault secret set --vault-name $KEY_VAULT_NAME --name “TF_VAR_rbac_client_app_id” --value $RBAC_CLIENT_APP_ID
az keyvault secret set --vault-name $KEY_VAULT_NAME --name “TF_VAR_tenant_id” --value $RBAC_AZURE_TENANT_ID

# And to export_tf_vars
export TF_VAR_rbac_server_app_id="${RBAC_SERVER_APP_ID}"
export TF_VAR_rbac_server_app_secret="${RBAC_SERVER_APP_SECRET}"
export TF_VAR_rbac_client_app_id="${RBAC_CLIENT_APP_ID}"
export TF_VAR_tenant_id="${RBAC_AZURE_TENANT_ID}"

# Output terraform variables
echo "
export TF_VAR_rbac_server_app_id="${RBAC_SERVER_APP_ID}"
export TF_VAR_rbac_server_app_secret="${RBAC_SERVER_APP_SECRET}"
export TF_VAR_rbac_client_app_id="${RBAC_CLIENT_APP_ID}"
export TF_VAR_tenant_id="${RBAC_AZURE_TENANT_ID}"
"

