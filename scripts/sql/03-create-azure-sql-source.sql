-- Execute no banco sqldb para criar a origem Azure SQL de exemplo.

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
    (2001, N'Fernanda Melo', '2026-02-01',  199.90, 'paid'),
    (2002, N'Gustavo Nunes', '2026-02-02', 1850.00, 'shipped'),
    (2003, N'Helena Costa',  '2026-02-03',   75.25, 'pending');
END;
GO

SELECT COUNT_BIG(*) AS SampleRows FROM dbo.Orders;
GO
