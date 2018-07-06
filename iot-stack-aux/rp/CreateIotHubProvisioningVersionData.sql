--//----------------------------------------------------------------
--// Copyright (c) Microsoft Corporation.  All rights reserved.
--//----------------------------------------------------------------

SET QUOTED_IDENTIFIER OFF;
GO
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT * FROM [VersionTable])
BEGIN
INSERT INTO [VersionTable]
	VALUES (1, 0, 0, 0, getutcdate())
END
GO

IF EXISTS (SELECT * FROM [VersionTable])
BEGIN
Update [VersionTable]
Set [Major] = 1,
	[Minor] = 0,
	[Build] = 0,
	[Revision] = 0,
	[LastUpdated] = getutcdate()
END
GO