param registryName string
param location string = resourceGroup().location
param sku string = 'Basic'
param tags object = {}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: registryName
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

output registryId string = containerRegistry.id
output registryName string = containerRegistry.name
output registryLoginServer string = containerRegistry.properties.loginServer
output registryPassword string = containerRegistry.listCredentials().passwords[0].value
output registryUsername string = containerRegistry.listCredentials().username
