# Segurança, desempenho e operação

## Segurança implementada

- identidade gerenciada do ADF com `Storage Blob Data Contributor` no storage;
- identidade gerenciada no linked service do Azure SQL;
- senha do SQL local referenciada no Key Vault;
- papel `Key Vault Secrets User` limitado à identidade do ADF;
- usuário `adf_reader` com somente leitura na origem local;
- TLS mínimo 1.2 nos serviços Azure;
- blobs públicos desabilitados;
- nenhum segredo literal nos artefatos ou scripts versionados;
- teste automático para impedir regressão nas referências e credenciais.

## Endurecimento recomendado para produção

1. desabilite acesso público no Storage, Key Vault, Azure SQL e Data Factory;
2. use Private Endpoints, Private DNS e Managed Virtual Network;
3. habilite purge protection no Key Vault e aumente a retenção;
4. restrinja o firewall do SQL aos caminhos necessários;
5. rotacione a senha local e monitore leitura de segredos;
6. habilite Defender for Cloud e diagnósticos para Log Analytics;
7. use grupos Microsoft Entra e papéis customizados quando o RBAC padrão for amplo;
8. mantenha pelo menos dois nós atualizados do SHIR em hosts diferentes;
9. aplique políticas de retenção e classificação às camadas do lake;
10. execute o ADF em ambientes separados e promova artefatos via CI/CD.

## Desempenho

O conjunto de exemplo é pequeno, portanto as origens usam `partitionOption: None`. Para tabelas grandes:

- habilite particionamento físico ou `DynamicRange` em uma coluna numérica/data bem distribuída;
- implemente carga incremental com watermark em `ChangedAtUtc`;
- ajuste `parallelCopies` após medir a capacidade do SQL e do SHIR;
- dimensione mais nós do SHIR antes de aumentar concorrência indiscriminadamente;
- evite muitos arquivos pequenos; agrupe lotes e defina tamanho-alvo;
- considere Parquet/Delta a partir da bronze para consultas analíticas;
- monitore o estágio mais lento, DIUs, conexões de pico, throughput e throttling;
- mantenha estatísticas e índices da origem atualizados.

## Qualidade e idempotência

O nome do arquivo inclui `pipeline().RunId`, por isso uma reexecução cria outro objeto em vez de sobrescrever o lote anterior. Essa escolha favorece auditoria, mas pode duplicar dados no consumo downstream. Uma solução produtiva deve registrar um manifesto de lotes, chave de negócio, checksum, status e watermark para impedir processamento duplicado.

Neste laboratório, zero linhas é tratado como erro. Para uma tabela que legitimamente pode estar vazia, altere a condição para registrar um lote vazio bem-sucedido ou compare a contagem com uma regra de tolerância.

## Monitoramento mínimo

Crie alertas para:

- falha de pipeline ou atividade;
- duração acima do percentil esperado;
- queda anormal de `rowsCopied`;
- SHIR indisponível ou desatualizado;
- throttling no SQL/Storage;
- falha de leitura do Key Vault;
- crescimento inesperado das camadas `raw` e `bronze`.
