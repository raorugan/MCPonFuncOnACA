#!/usr/bin/env bash

# Retrieve credentials securely (for example, via Azure CLI)
#acrName=$AZURE_CONTAINER_REGISTRY_NAME
#registryEndpoint=$(az acr show --name $acrName --query "loginServer" -o tsv)
# Retrieve username and password using Azure CLI. You could also pull
# these from Azure Key Vault instead.
#registryUsername=$(az acr credential show --name $acrName --query "username" -o tsv)
#registryPassword=$(az acr credential show --name $acrName --query "passwords[0].value" -o tsv)

# Set the environment values in your azd environment
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT $AZURE_CONTAINER_REGISTRY_ENDPOINT
azd env set AZURE_CONTAINER_REGISTRY_USERNAME $AZURE_CONTAINER_REGISTRY_USERNAME
azd env set AZURE_CONTAINER_REGISTRY_PASSWORD $AZURE_CONTAINER_REGISTRY_PASSWORD

az containerapp update \
  --name $AZURE_CONTAINER_APP_NAME \
  --resource-group $AZURE_RESOURCE_GROUP \
  --image $AZURE_CONTAINER_REGISTRY_ENDPOINT/$AZURE_CONTAINER_APP_NAME:latest \
  --registry-server $AZURE_CONTAINER_REGISTRY_ENDPOINT 











  