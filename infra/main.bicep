targetScope = 'resourceGroup'

@description('Região Azure para todos os recursos.')
param location string = resourceGroup().location

@description('Prefixo curto usado nos nomes dos recursos.')
@minLength(3)
@maxLength(12)
param prefix string = 'sql2lake'

@description('Ambiente do laboratório.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Login administrativo do Azure SQL. A senha é recebida separadamente como parâmetro seguro.')
param sqlAdminLogin string = 'sqladminuser'

@secure()
@description('Senha administrativa do Azure SQL. Nunca salve este valor em arquivo versionado.')
param sqlAdminPassword string

@description('Object ID do usuário ou grupo que será administrador Microsoft Entra do Azure SQL. Vazio não configura administrador Entra.')
param entraAdminObjectId string = ''

@description('Nome de exibição do administrador Microsoft Entra.')
param entraAdminLogin string = ''

@description('Tags aplicadas aos recursos.')
param tags object = {
  project: 'azure-adf-sql-to-datalake'
  environment: environment
  managedBy: 'bicep'
}

var compactPrefix = take(replace(toLower(prefix), '-', ''), 12)
var suffix = take(uniqueString(subscription().subscriptionId, resourceGroup().id), 6)
var storageAccountName = take('st${compactPrefix}${suffix}', 24)
var dataFactoryName = 'adf-${toLower(prefix)}-${environment}-${suffix}'
var keyVaultName = take('kv-${toLower(prefix)}-${suffix}', 24)
var sqlServerName = take('sql-${toLower(prefix)}-${environment}-${suffix}', 63)

module storageModule 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    storageAccountName: storageAccountName
    tags: tags
  }
}

module keyVaultModule 'modules/key-vault.bicep' = {
  name: 'key-vault-deployment'
  params: {
    location: location
    keyVaultName: keyVaultName
    tags: tags
  }
}

module sqlModule 'modules/sql-database.bicep' = {
  name: 'sql-deployment'
  params: {
    location: location
    sqlServerName: sqlServerName
    databaseName: 'sqldb'
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    entraAdminObjectId: entraAdminObjectId
    entraAdminLogin: entraAdminLogin
    tags: tags
  }
}

module dataFactoryModule 'modules/data-factory.bicep' = {
  name: 'data-factory-deployment'
  params: {
    location: location
    dataFactoryName: dataFactoryName
    tags: tags
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageModule.outputs.storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultModule.outputs.keyVaultName
}

resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, dataFactoryModule.outputs.principalId, storageBlobDataContributorRole.id)
  scope: storageAccount
  properties: {
    principalId: dataFactoryModule.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRole.id
  }
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, dataFactoryModule.outputs.principalId, keyVaultSecretsUserRole.id)
  scope: keyVault
  properties: {
    principalId: dataFactoryModule.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsUserRole.id
  }
}

output dataFactoryName string = dataFactoryModule.outputs.dataFactoryName
output dataFactoryPrincipalId string = dataFactoryModule.outputs.principalId
output storageAccountName string = storageModule.outputs.storageAccountName
output storageDfsEndpoint string = storageModule.outputs.dfsEndpoint
output keyVaultName string = keyVaultModule.outputs.keyVaultName
output azureSqlServerName string = sqlModule.outputs.sqlServerName
output azureSqlServerFqdn string = sqlModule.outputs.sqlServerFqdn
output azureSqlDatabaseName string = sqlModule.outputs.databaseName
output selfHostedIntegrationRuntimeName string = dataFactoryModule.outputs.selfHostedIntegrationRuntimeName
