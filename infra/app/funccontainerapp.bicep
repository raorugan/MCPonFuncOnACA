param name string 
param location string = resourceGroup().location
param environmentid string
param identityId string
param identityClientId string 
param registryName string
param storageAccountName string

param containerimg string

var applicationInsightsIdentity = 'ClientId=${identityClientId};Authorization=AAD'

// Shorten the container app name to ensure it meets the 32-character limit
//var shortName = toLower(take('${name}-func', 32))

resource func_containerapps 'Microsoft.App/containerapps@2024-10-02-preview' = {
  name: name
  location: location
  kind: 'functionapp'
  tags: {
    'azd-service-name': 'code' // This tag must match the service name in azure.yaml
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environmentid 
    environmentId: environmentid 
    workloadProfileName: 'Consumption'

   
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        exposedPort: 0
        transport: 'Auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: '${registryName}.azurecr.io'
          identity: identityId
        }
      ]
      secrets: [
        {
          name: 'storage-clientid'
          value: identityClientId
        }
        {
          name: 'appinsights-auth-string'
          value: applicationInsightsIdentity
        }
        {
          name: 'storage-accountname'
          value: storageAccountName
        }
        {
          name: 'storage-credential'
          value: identityId
        }
        {
          name: 'bloburi'
          value: 'https://${storageAccountName}.blob.core.windows.net/'
        }
        {
          name: 'acr-password'
          value: identityId
        }
     {
          name: 'acr-username'
          value: registryName
        }
        
      ]
      identitySettings: []
      maxInactiveRevisions: 100
   
      
    }
    template: {
      containers: [
        {
          name: 'functionapp' // explicitly set valid DNS1123 container name
          image: containerimg
          env: [
            {
              name: 'AzureWebJobsStorage__clientId'
              secretRef: 'storage-clientid'
            }
            {
              name: 'AzureWebJobsStorage__accountName'
              secretRef: 'storage-accountname'
            }
            {
              name: 'AzureWebJobsStorage__credential'
              value: 'managedidentity'
            }
            {
              name: 'AzureWebJobsStorage__blobServiceUri'
              secretRef:'bloburi'
            }
            {
              name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
              secretRef: 'appinsights-auth-string'
            }
            {
              name: 'ACR_USE_MANAGED_IDENTITY'
              value: 'true'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        cooldownPeriod: 300
        pollingInterval: 30

        
        rules: [
          {
           name:'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

output SERVICE_API_NAME string = func_containerapps.name

