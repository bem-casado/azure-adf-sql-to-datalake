:on error exit

IF DB_ID(N'SourceDb') IS NULL
BEGIN
  CREATE DATABASE SourceDb;
END;
GO

IF SUSER_ID(N'adf_reader') IS NULL
BEGIN
  CREATE LOGIN adf_reader
    WITH PASSWORD = N'$(AdfReaderPassword)',
         CHECK_POLICY = ON,
         CHECK_EXPIRATION = OFF;
END;
GO

USE SourceDb;
GO

IF USER_ID(N'adf_reader') IS NULL
BEGIN
  CREATE USER adf_reader FOR LOGIN adf_reader;
END;
GO

ALTER ROLE db_datareader ADD MEMBER adf_reader;
GO

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Orders
  (
    OrderId      int            NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerName nvarchar(120)  NOT NULL,
    OrderDate    date           NOT NULL,
    Amount       decimal(12, 2) NOT NULL,
    Status       varchar(20)    NOT NULL,
    ChangedAtUtc datetime2(0)   NOT NULL CONSTRAINT DF_Orders_ChangedAtUtc DEFAULT SYSUTCDATETIME()
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Orders)
BEGIN
  INSERT INTO dbo.Orders (OrderId, CustomerName, OrderDate, Amount, Status)
  VALUES
    (1001, N'Ana Silva',  '2026-01-10',  249.90, 'paid'),
    (1002, N'Bruno Lima', '2026-01-11', 1290.00, 'shipped'),
    (1003, N'Carla Souza','2026-01-12',   89.50, 'pending'),
    (1004, N'Diego Alves','2026-01-13',  520.35, 'paid'),
    (1005, N'Elisa Rocha','2026-01-14',  310.10, 'cancelled');
END;
GO

SELECT COUNT_BIG(*) AS SampleRows FROM dbo.Orders;
GO
