param location string
param keyVaultName string
param tags object

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enablePurgeProtection: false
    enableSoftDelete: true
    publicNetworkAccess: 'Enabled'
    softDeleteRetentionInDays: 7
    sku: {
      family: 'A'
      name: 'standard'
    }
  }
}

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output vaultUri string = keyVault.properties.vaultUri
