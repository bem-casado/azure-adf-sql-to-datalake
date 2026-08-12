[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-zA-Z0-9._()-]{1,90}$')]
  [string]$ResourceGroupName,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-zA-Z0-9-]{3,12}$')]
  [string]$Prefix,

  [string]$Location = 'brazilsouth',

  [string]$Environment = 'dev',

  [string]$SqlAdminLogin = 'sqladminuser',

  [switch]$SkipEntraAdmin
)

$ErrorActionPreference = 'Stop'
$templateFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'infra/main.bicep'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Azure CLI não encontrado. Instale-o antes de executar este script.'
}

& az account show --output none
if ($LASTEXITCODE -ne 0) {
  throw 'Sessão Azure CLI inválida. Execute az login e tente novamente.'
}

$entraAdminObjectId = ''
$entraAdminLogin = ''
if (-not $SkipEntraAdmin) {
  $signedInUserJson = & az ad signed-in-user show --query '{id:id,displayName:displayName}' --output json 2>$null
  if ($LASTEXITCODE -eq 0 -and $signedInUserJson) {
    $signedInUser = $signedInUserJson | ConvertFrom-Json
    $entraAdminObjectId = $signedInUser.id
    $entraAdminLogin = $signedInUser.displayName
    Write-Host "Administrador Microsoft Entra do Azure SQL: $entraAdminLogin"
  }
  else {
    Write-Warning 'Não foi possível identificar um usuário conectado. O administrador Microsoft Entra não será configurado automaticamente.'
  }
}

$secureSqlPassword = Read-Host 'Senha administrativa do Azure SQL' -AsSecureString
$plainSqlPassword = [System.Net.NetworkCredential]::new('', $secureSqlPassword).Password

try {
  Write-Host "Criando ou atualizando o grupo de recursos $ResourceGroupName..."
  & az group create --name $ResourceGroupName --location $Location --output none
  if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao criar o grupo de recursos.'
  }

  $deploymentArgs = @(
    'deployment', 'group', 'create',
    '--resource-group', $ResourceGroupName,
    '--name', 'azure-adf-sql-to-datalake',
    '--template-file', $templateFile,
    '--parameters',
    "prefix=$Prefix",
    "environment=$Environment",
    "location=$Location",
    "sqlAdminLogin=$SqlAdminLogin",
    "sqlAdminPassword=$plainSqlPassword",
    "entraAdminObjectId=$entraAdminObjectId",
    "entraAdminLogin=$entraAdminLogin",
    '--query', 'properties.outputs',
    '--output', 'json'
  )

  Write-Host 'Implantando Data Factory, ADLS Gen2, Key Vault, Azure SQL e RBAC...'
  $outputsJson = & az @deploymentArgs
  if ($LASTEXITCODE -ne 0) {
    throw 'A implantação Bicep falhou. Consulte a mensagem do Azure CLI acima.'
  }

  $outputs = $outputsJson | ConvertFrom-Json
  [pscustomobject]@{
    ResourceGroup = $ResourceGroupName
    DataFactory = $outputs.dataFactoryName.value
    StorageAccount = $outputs.storageAccountName.value
    KeyVault = $outputs.keyVaultName.value
    AzureSqlServer = $outputs.azureSqlServerName.value
    AzureSqlDatabase = $outputs.azureSqlDatabaseName.value
    IntegrationRuntime = $outputs.selfHostedIntegrationRuntimeName.value
  } | Format-List

  Write-Host 'Infraestrutura concluída. Cadastre o segredo local e execute scripts/deploy-adf.ps1.'
}
finally {
  $plainSqlPassword = $null
  $secureSqlPassword = $null
}
