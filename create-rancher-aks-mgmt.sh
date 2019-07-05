#!/bin/sh

export ARM_ACCESS_KEY=$(az keyvault secret show --name terraform-backend-key --vault-name $KEY_VAULT_NAME --query value -o tsv)
source export_tf_vars

terraform plan -out rancher-management-plan
terraform apply rancher-management-plan -auto-approve

# Create an RBAC binding for the kube-sytem service account
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
# Bind RBAC role for admins and users
