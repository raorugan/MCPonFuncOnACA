param exists bool
param name string


var containerimg = exists ? [ name ] : []

resource existingApp 'Microsoft.App/containerApps@2023-05-02-preview' existing = if (exists) {
  name: name
}

output containerimg array = containerimg
