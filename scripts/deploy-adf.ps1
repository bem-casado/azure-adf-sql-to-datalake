[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ResourceGroupName,

  [Parameter(Mandatory = $true)]
  [string]$FactoryName,

  [Parameter(Mandatory = $true)]
  [string]$StorageAccountName,

  [Parameter(Mandatory = $true)]
  [string]$KeyVaultName,

  [Parameter(Mandatory = $true)]
  [string]$AzureSqlServerName,

  [string]$AzureSqlDatabaseName = 'sqldb',
  [string]$OnPremSqlServer = 'host.docker.internal,1433',
  [string]$OnPremSqlDatabase = 'SourceDb',
  [string]$OnPremSqlUser = 'adf_reader',
  [string]$OnPremPasswordSecretName = 'sql-onprem-password'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$adfRoot = Join-Path $repoRoot 'adf'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Azure CLI não encontrado.'
}

& az account show --output none
if ($LASTEXITCODE -ne 0) {
  throw 'Execute az login antes de publicar os artefatos.'
}

$replacements = [ordered]@{
  '__STORAGE_ACCOUNT_NAME__' = $StorageAccountName
  '__KEY_VAULT_NAME__' = $KeyVaultName
  '__AZURE_SQL_SERVER_NAME__' = $AzureSqlServerName
  '__AZURE_SQL_DATABASE_NAME__' = $AzureSqlDatabaseName
  '__ON_PREM_SQL_SERVER__' = $OnPremSqlServer
  '__ON_PREM_SQL_DATABASE__' = $OnPremSqlDatabase
  '__ON_PREM_SQL_USER__' = $OnPremSqlUser
  '__ON_PREM_PASSWORD_SECRET_NAME__' = $OnPremPasswordSecretName
}

function Read-AdfArtifact {
  param([Parameter(Mandatory = $true)][string]$Path)

  $content = Get-Content -LiteralPath $Path -Raw
  foreach ($entry in $replacements.GetEnumerator()) {
    $content = $content.Replace($entry.Key, $entry.Value)
  }

  if ($content -match '__[A-Z0-9_]+__') {
    throw "Placeholder não resolvido no artefato ${Path}: $($Matches[0])"
  }

  return $content | ConvertFrom-Json
}

function Publish-AdfArtifact {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('linked-service', 'dataset', 'pipeline')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $path = Join-Path $adfRoot $RelativePath
  $artifact = Read-AdfArtifact -Path $path
  $propertiesJson = $artifact.properties | ConvertTo-Json -Depth 100 -Compress

  Write-Host "Publicando $Kind/$($artifact.name)..."
  & az datafactory $Kind create `
    --resource-group $ResourceGroupName `
    --factory-name $FactoryName `
    --name $artifact.name `
    --properties $propertiesJson `
    --output none

  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao publicar $Kind/$($artifact.name)."
  }
}

& az datafactory integration-runtime show `
  --resource-group $ResourceGroupName `
  --factory-name $FactoryName `
  --name 'ir-selfhosted-onprem' `
  --output none 2>$null

if ($LASTEXITCODE -ne 0) {
  Write-Host 'Criando o Self-hosted Integration Runtime...'
  & az datafactory integration-runtime self-hosted create `
    --resource-group $ResourceGroupName `
    --factory-name $FactoryName `
    --name 'ir-selfhosted-onprem' `
    --description 'Acesso de saída ao SQL Server local' `
    --output none
  if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao criar o Self-hosted Integration Runtime.'
  }
}

$linkedServices = @(
  'linkedService/ls_key_vault.json',
  'linkedService/ls_adls_gen2.json',
  'linkedService/ls_azure_sql.json',
  'linkedService/ls_sql_onprem.json'
)

$datasets = @(
  'dataset/ds_adls_delimited.json',
  'dataset/ds_azure_sql_table.json',
  'dataset/ds_sql_onprem_table.json'
)

$pipelines = @(
  'pipeline/pl_promote_raw_to_bronze.json',
  'pipeline/pl_ingest_azure_sql_to_raw.json',
  'pipeline/pl_ingest_onprem_sql_to_raw.json'
)

foreach ($item in $linkedServices) {
  Publish-AdfArtifact -Kind 'linked-service' -RelativePath $item
}
foreach ($item in $datasets) {
  Publish-AdfArtifact -Kind 'dataset' -RelativePath $item
}
foreach ($item in $pipelines) {
  Publish-AdfArtifact -Kind 'pipeline' -RelativePath $item
}

Write-Host 'Artefatos do Azure Data Factory publicados com sucesso.'
