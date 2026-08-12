# Troubleshooting

| Sintoma | Causa provável | Ação |
|---|---|---|
| `Integration runtime is not available` | SHIR parado, sem registro ou sem saída HTTPS | abra o Configuration Manager do IR, confirme **Running**, proxy e porta 443 |
| erro de conexão no `ls_sql_onprem` | host/porta não alcançável pelo nó do SHIR | teste DNS e TCP 1433 a partir do host do IR; não use `localhost` se o SQL estiver em outra máquina |
| login failed para `adf_reader` | segredo diferente da senha criada no SQL | atualize `sql-onprem-password` no Key Vault e teste novamente |
| acesso negado ao Key Vault | propagação de RBAC ou papel ausente | aguarde alguns minutos e confirme `Key Vault Secrets User` para a identidade do ADF |
| acesso negado ao ADLS | papel ou ACL ausente | confirme `Storage Blob Data Contributor`; em redes restritas, valide endpoint e DNS |
| login Microsoft Entra falha no Azure SQL | usuário da identidade gerenciada não criado | execute `02-grant-adf-azure-sql.sql` com o nome exato do Data Factory |
| pipeline falha com `NO_ROWS_COPIED` | tabela vazia, schema/tabela incorretos ou usuário sem leitura | consulte a tabela na origem e revise os parâmetros |
| pipeline falha com `INVALID_BRONZE_FILE` | arquivo não foi gravado ou ficou vazio | abra a saída da Copy Activity e verifique permissões, espaço e caminho |
| caracteres quebrados no TXT | consumidor interpretando encoding diferente | leia como UTF-8 e confirme delimitador `;` e aspas |
| timeout ou baixa vazão | gargalo no SQL, rede, SHIR ou muitos dados sem partição | abra os detalhes da Copy Activity, identifique a etapa lenta e aplique as recomendações de desempenho |
| Bicep falha em role assignment | identidade sem permissão de atribuir RBAC | use uma identidade com `Owner` ou `User Access Administrator` no escopo necessário |
| nome global já existe | colisão rara de nome do Storage/Key Vault/SQL | use outro `Prefix` ou outro grupo de recursos para gerar novo sufixo |

## Coleta de evidências

Ao diagnosticar, registre sem segredos:

- Run ID da pipeline e Activity Run ID;
- código e mensagem do erro;
- duração e métricas `rowsRead`, `rowsCopied`, `dataRead`, `dataWritten` e throughput;
- estado e versão do nó SHIR;
- horário UTC do problema;
- nomes dos recursos e caminho do arquivo, sem chaves, tokens ou senhas.
