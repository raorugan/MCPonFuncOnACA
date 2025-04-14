param name string
param location string = resourceGroup().location
param tags object = {}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

output id string = logAnalytics.id
output name string = logAnalytics.name
