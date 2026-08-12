param location string
param sqlServerName string
param databaseName string
param sqlAdminLogin string
@secure()
param sqlAdminPassword string
param entraAdminObjectId string
param entraAdminLogin string
param tags object

resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
    version: '12.0'
  }
}

resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01' = {
  name: 'AllowAzureServices'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource entraAdministrator 'Microsoft.Sql/servers/administrators@2023-08-01' = if (!empty(entraAdminObjectId)) {
  name: 'ActiveDirectory'
  parent: sqlServer
  properties: {
    administratorType: 'ActiveDirectory'
    azureADOnlyAuthentication: false
    login: entraAdminLogin
    sid: entraAdminObjectId
    tenantId: tenant().tenantId
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = {
  name: databaseName
  parent: sqlServer
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
    zoneRedundant: false
  }
}

output sqlServerName string = sqlServer.name
output sqlServerFqdn string = '${sqlServer.name}.database.windows.net'
output databaseName string = sqlDatabase.name
