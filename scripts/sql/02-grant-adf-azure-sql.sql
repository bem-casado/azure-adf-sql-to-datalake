-- Execute no banco sqldb conectado com o administrador Microsoft Entra.
-- Ative o SQLCMD Mode e substitua o valor abaixo pelo nome real do Data Factory.
:setvar DataFactoryName "adf-sql2lake-dev-substitua"

IF NOT EXISTS
(
  SELECT 1
  FROM sys.database_principals
  WHERE name = N'$(DataFactoryName)'
)
BEGIN
  EXEC(N'CREATE USER ' + QUOTENAME(N'$(DataFactoryName)') + N' FROM EXTERNAL PROVIDER');
END;
GO

ALTER ROLE db_datareader ADD MEMBER [$(DataFactoryName)];
GO
