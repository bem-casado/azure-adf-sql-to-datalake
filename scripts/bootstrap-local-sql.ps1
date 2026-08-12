[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$sqlFile = Join-Path $PSScriptRoot 'sql/01-bootstrap-local-source.sql'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw 'Docker não encontrado.'
}

$saPasswordSecure = Read-Host 'Senha do usuário sa definida no arquivo .env' -AsSecureString
$readerPasswordSecure = Read-Host 'Nova senha do usuário adf_reader' -AsSecureString
$saPassword = [System.Net.NetworkCredential]::new('', $saPasswordSecure).Password
$readerPassword = [System.Net.NetworkCredential]::new('', $readerPasswordSecure).Password

if ($readerPassword.Contains("'")) {
  throw "A senha do laboratório não pode conter apóstrofo ('). Escolha outra senha forte."
}

try {
  & docker compose --project-directory $repoRoot up -d
  if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao iniciar o SQL Server com Docker Compose.'
  }

  Write-Host 'Aguardando o SQL Server ficar saudável...'
  $healthy = $false
  for ($attempt = 1; $attempt -le 24; $attempt++) {
    $status = & docker inspect --format '{{.State.Health.Status}}' 'adf-sql-source' 2>$null
    if ($status -eq 'healthy') {
      $healthy = $true
      break
    }
    Start-Sleep -Seconds 5
  }

  if (-not $healthy) {
    throw 'O SQL Server não ficou saudável dentro do tempo esperado. Execute docker logs adf-sql-source.'
  }

  & docker cp $sqlFile 'adf-sql-source:/tmp/01-bootstrap-local-source.sql'
  if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao copiar o script SQL para o contêiner.'
  }

  & docker exec 'adf-sql-source' /opt/mssql-tools18/bin/sqlcmd `
    -S localhost -U sa -P $saPassword -C -b `
    -v "AdfReaderPassword=$readerPassword" `
    -i /tmp/01-bootstrap-local-source.sql

  if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao inicializar o banco local.'
  }

  Write-Host 'SourceDb.dbo.Orders e o login adf_reader estão prontos.'
}
finally {
  $saPassword = $null
  $readerPassword = $null
  $saPasswordSecure = $null
  $readerPasswordSecure = $null
}
