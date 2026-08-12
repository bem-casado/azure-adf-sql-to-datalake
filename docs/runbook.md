# Runbook do laboratório

## 1. Validar o projeto antes do deploy

Na raiz do repositório:

```powershell
python tests/validate_artifacts.py
az bicep build --file infra/main.bicep --stdout | Out-Null
```

Resultado esperado do primeiro comando: `OK: 11 artefatos ADF válidos...`.

## 2. Preparar a origem local

1. copie `.env.example` para `.env` e troque o valor de exemplo;
2. execute `docker compose up -d`;
3. execute `./scripts/bootstrap-local-sql.ps1`;
4. confirme com `docker ps` que `adf-sql-source` está saudável.

O contêiner publica `1433` apenas para o host do laboratório. Em rede corporativa, use o nome real do servidor e verifique DNS, rota, firewall e TLS a partir da máquina do SHIR.

## 3. Criar a infraestrutura Azure

```powershell
az login
az account set --subscription "<ASSINATURA>"
./scripts/deploy-infrastructure.ps1 `
  -ResourceGroupName "rg-adf-sql-lab" `
  -Prefix "sql2lake" `
  -Location "brazilsouth"
```

O script tenta configurar o usuário conectado como administrador Microsoft Entra do SQL lógico. Se a identidade usada no Azure CLI não for um usuário, utilize `-SkipEntraAdmin` e configure um usuário ou grupo manualmente no portal.

Guarde os nomes mostrados na saída. Os nomes globais recebem um sufixo determinístico.

## 4. Configurar credenciais e artefatos

Cadastre a senha do `adf_reader`:

```powershell
./scripts/set-onprem-secret.ps1 -KeyVaultName "<KEY-VAULT>"
```

Publique linked services, datasets e pipelines:

```powershell
./scripts/deploy-adf.ps1 `
  -ResourceGroupName "rg-adf-sql-lab" `
  -FactoryName "<ADF>" `
  -StorageAccountName "<STORAGE>" `
  -KeyVaultName "<KEY-VAULT>" `
  -AzureSqlServerName "<SQL-SERVER>"
```

O Bicep cria o IR; o segundo script também o cria caso os artefatos sejam publicados em uma fábrica preparada manualmente.

## 5. Registrar o Self-hosted IR

1. abra o Data Factory no portal e selecione **Launch Studio**;
2. acesse **Manage → Integration runtimes**;
3. abra `ir-selfhosted-onprem` e baixe o instalador;
4. instale na máquina Windows que alcança o SQL local;
5. registre usando uma das chaves da tela;
6. confirme o status **Running**;
7. em `ls_sql_onprem`, use **Test connection**.

As chaves de registro são credenciais. Não as copie para issues, logs ou arquivos do repositório.

Se o IR estiver na mesma máquina do Docker Desktop, `host.docker.internal,1433` costuma funcionar. Em outra máquina, informe o IP/DNS acessível do host do SQL.

## 6. Autorizar a origem Azure SQL

Conecte-se ao banco `sqldb` com o administrador Microsoft Entra e execute, em SQLCMD Mode:

1. `scripts/sql/02-grant-adf-azure-sql.sql`, após trocar o nome da fábrica;
2. `scripts/sql/03-create-azure-sql-source.sql`, para criar os dados de exemplo.

Se a conexão do seu computador for bloqueada, adicione temporariamente o seu IP ao firewall do SQL lógico e remova a regra depois.

No ADF Studio, teste `ls_azure_sql` e `ls_adls_gen2`.

## 7. Executar as pipelines

Pelo ADF Studio, abra **Author → SQL to Data Lake** e execute:

- `pl_ingest_onprem_sql_to_raw`, ou
- `pl_ingest_azure_sql_to_raw`.

Parâmetros padrão:

| Parâmetro | Valor |
|---|---|
| `schemaName` | `dbo` |
| `tableName` | `Orders` |
| `columnDelimiter` | `;` |

Também é possível iniciar pelo CLI:

```powershell
az datafactory pipeline create-run `
  --resource-group "rg-adf-sql-lab" `
  --factory-name "<ADF>" `
  --name "pl_ingest_onprem_sql_to_raw" `
  --parameters '{"schemaName":"dbo","tableName":"Orders","columnDelimiter":";"}'
```

## 8. Validar o resultado

No ADF Studio → **Monitor**, abra a execução e confirme:

- status `Succeeded` nas cópias;
- `rowsRead` e `rowsCopied` iguais;
- `dataConsistencyVerification` sem divergências;
- throughput, duração, dados lidos e dados escritos;
- pipeline filha concluída.

Liste os arquivos do Data Lake:

```powershell
az storage fs file list `
  --account-name "<STORAGE>" `
  --file-system raw `
  --auth-mode login `
  --output table

az storage fs file list `
  --account-name "<STORAGE>" `
  --file-system bronze `
  --auth-mode login `
  --output table
```

O conjunto local contém cinco linhas; o conjunto Azure SQL contém três.

## 9. Encerrar e limpar

Pare o contêiner sem apagar o volume:

```powershell
docker compose stop
```

Quando não precisar mais dos recursos Azure, revise o alvo e exclua o grupo pelo portal ou CLI. A exclusão do grupo de recursos é irreversível após o período de recuperação aplicável a cada serviço.
