param location string
param dataFactoryName string
param tags object

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

resource selfHostedIntegrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: 'ir-selfhosted-onprem'
  parent: dataFactory
  properties: {
    description: 'Acesso de saída ao SQL Server local. Instale dois nós para alta disponibilidade em produção.'
    type: 'SelfHosted'
  }
}

output dataFactoryName string = dataFactory.name
output principalId string = dataFactory.identity.principalId
output selfHostedIntegrationRuntimeName string = selfHostedIntegrationRuntime.name
