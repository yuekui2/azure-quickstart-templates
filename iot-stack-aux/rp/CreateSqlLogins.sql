CREATE LOGIN $(UserName) WITH PASSWORD = '$(Password)'
GO

Use MasterDatabase;
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$(UserName)')
BEGIN
    CREATE USER [$(UserName)] FOR LOGIN [$(UserName)]
    EXEC sp_addrolemember N'db_owner', N'$(UserName)'
END;
GO