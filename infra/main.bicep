targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string
param apiServiceName string = ''
param apiUserAssignedIdentityName string = ''
param applicationInsightsName string = ''
//param logAnalyticsName string = ''
param resourceGroupName string = ''
//param storageAccountName string = ''
//param registryName string = ''
param disableLocalAuth bool = true
param apiImageName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var functionAppName = !empty(apiServiceName) ? apiServiceName : 'fapi-${resourceToken}'
//var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(toLower(uniqueString(functionAppName, resourceToken)), 7)}'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the function app to reach storage 
module apiUserAssignedIdentity './core/identity/userassignedidentity.bicep' = {
  name: 'apiUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(apiUserAssignedIdentityName) ? apiUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}api-${resourceToken}'
  }
}

module logAnalyticsenv './core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: take('flog${resourceToken}', 15)
    location: location
    tags: tags
  }
}

module containerAppEnv './app/containerappenv.bicep' = {
  name: 'containerAppEnv'
  scope: rg
  params: {
    location: location
    name: !empty(environmentName) ? environmentName : '${abbrs.appContainerApps}${resourceToken}'
    logAnalyticsId: logAnalyticsenv.outputs.id
  }
}

module registry './core/registry/registry.bicep' = {
  name: 'registry'
  scope: rg
  params: {
    registryName: take('facr${resourceToken}',15)
    location: location
    tags: tags
  }
}

module registryRoleAssignment './core/registry/registry-access.bicep' = {
  name: 'registryRoleAssignment'
  scope: rg
  params: {
    containerRegistryName: registry.outputs.registryName
    principalId: apiUserAssignedIdentity.outputs.identityPrincipalId
  }
}

module fetchimg './core/registry/fetch-container-image.bicep' = {
  name: 'fetchContainerApp'
  scope: rg
  params: {
    exists: true
    name: !empty(apiImageName) ? apiImageName : '${registry.outputs.registryLoginServer}/${abbrs.appContainerApps}${functionAppName}'
  }
}
// Backing storage for Azure functions api
module storage './core/storage/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: take('mcpfsto${resourceToken}', 15)
    location: location
    tags: tags
    //containers: [{name: deploymentStorageContainerName}, {name: 'snippets'}]
    publicNetworkAccess: 'Enabled'
    networkAcls:  {
      defaultAction: 'Allow'
    }
  }
  }


var StorageBlobDataOwner = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var StorageQueueDataContributor = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'

// Allow access from api to blob storage using a managed identity
module blobRoleAssignmentApi './core/storage/storage-access.bicep' = {
  name: 'blobRoleAssignmentapi'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: StorageBlobDataOwner
    principalID: apiUserAssignedIdentity.outputs.identityPrincipalId
  }
}

// Allow access from api to queue storage using a managed identity
module queueRoleAssignmentApi './core/storage/storage-access.bicep' = {
  name: 'queueRoleAssignmentapi'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: StorageQueueDataContributor
    principalID: apiUserAssignedIdentity.outputs.identityPrincipalId
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/appinsights.bicep' = {
  name: 'appinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsenv.outputs.id
    disableLocalAuth: disableLocalAuth
  }
}

var monitoringRoleDefinitionId = '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher role ID

// Allow access from api to application insights using a managed identity
module appInsightsRoleAssignmentApi './core/monitor/appinsights-access.bicep' = {
  name: 'appInsightsRoleAssignmentapi'
  scope: rg
  params: {
    appInsightsName: monitoring.outputs.name
    roleDefinitionID: monitoringRoleDefinitionId
    principalID: apiUserAssignedIdentity.outputs.identityPrincipalId
  }
}


module funconacapi './app/funccontainerapp.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: functionAppName
    location: location
    environmentid: containerAppEnv.outputs.environmentId
    registryName: registry.outputs.registryName
    storageAccountName:storage.outputs.name
    containerimg: 'mcr.microsoft.com/azure-functions/dotnet8-quickstart-demo:1.0'
    identityId: apiUserAssignedIdentity.outputs.identityId
    identityClientId: apiUserAssignedIdentity.outputs.identityClientId
  }
}


// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_API_NAME string = funconacapi.name
output AZURE_FUNCTION_NAME string = functionAppName
output AZURE_RESOURCE_GROUP string = rg.name

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = registry.outputs.registryName
output AZURE_CONTAINER_REGISTRY_USERNAME string = registry.outputs.registryUsername
output AZURE_CONTAINER_REGISTRY_PASSWORD string = registry.outputs.registryPassword

