[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$KeyVaultName,

  [string]$SecretName = 'sql-onprem-password'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Azure CLI não encontrado.'
}

$secureValue = Read-Host "Valor para o segredo $SecretName" -AsSecureString
$plainValue = [System.Net.NetworkCredential]::new('', $secureValue).Password
$temporaryFile = New-TemporaryFile

try {
  [System.IO.File]::WriteAllText($temporaryFile.FullName, $plainValue)
  & az keyvault secret set `
    --vault-name $KeyVaultName `
    --name $SecretName `
    --file $temporaryFile.FullName `
    --encoding utf-8 `
    --output none

  if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao gravar o segredo no Key Vault.'
  }

  Write-Host "Segredo $SecretName gravado no Key Vault $KeyVaultName."
}
finally {
  $plainValue = $null
  $secureValue = $null
  if (Test-Path -LiteralPath $temporaryFile.FullName) {
    Remove-Item -LiteralPath $temporaryFile.FullName -Force
  }
}
