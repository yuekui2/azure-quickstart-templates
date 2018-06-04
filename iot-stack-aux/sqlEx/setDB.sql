EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE'
    , N'Software\Microsoft\MSSQLServer\MSSQLServer'
    , N'DefaultData'
    , REG_SZ
    , N'F:\SQL\Data'
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE'
    , N'Software\Microsoft\MSSQLServer\MSSQLServer'
    , N'DefaultLog'
    , REG_SZ
    , N'F:\SQL\Logs'
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE'
    , N'Software\Microsoft\MSSQLServer\MSSQLServer'
    , N'BackupDirectory'
    , REG_SZ
    , N'F:\SQL\Backups'
GO