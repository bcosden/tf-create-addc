# set environment variables for terraform input
export ARM_SUBSCRIPTION_ID=$(az keyvault secret show --name tf-subscription-id --vault-name az-mgmt-keyvault --query value -o tsv)
export ARM_CLIENT_ID=$(az keyvault secret show --name tf-client-id --vault-name az-mgmt-keyvault --query value -o tsv)
export ARM_CLIENT_SECRET=$(az keyvault secret show --name tf-client-secret --vault-name az-mgmt-keyvault --query value -o tsv)
export ARM_TENANT_ID=$(az keyvault secret show --name tf-tenant-id --vault-name az-mgmt-keyvault --query value -o tsv)
export ARM_ACCESS_KEY=$(az keyvault secret show --name tf-access-key --vault-name az-mgmt-keyvault --query value -o tsv)
