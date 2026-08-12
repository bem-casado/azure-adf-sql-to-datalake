# Como contribuir

1. crie uma branch a partir de `main`;
2. não inclua `.env`, senhas, chaves, tokens, IDs sensíveis ou exportações de produção;
3. execute `python tests/validate_artifacts.py`;
4. execute `az bicep build --file infra/main.bicep --stdout`;
5. descreva no pull request o cenário testado e qualquer impacto de custo ou segurança.

Mudanças nos JSONs do ADF devem manter os nomes dos arquivos iguais ao campo `name` e todas as referências internas válidas.
