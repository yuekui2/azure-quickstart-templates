--//----------------------------------------------------------------
--// Copyright (c) Microsoft Corporation.  All rights reserved.
--//----------------------------------------------------------------

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ProvisioningServicesTable
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ProvisioningServicesTable]') AND type in (N'U'))
BEGIN
CREATE TABLE ProvisioningServicesTable (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [ProvisioningServiceName] [nvarchar](63) NOT NULL UNIQUE, -- Max DNS part length is 63
    [ResourceGroup] [nvarchar](128) NOT NULL,
    [UserSubscriptionsTableId] [int] NOT NULL,
    [State] [nvarchar](50) NOT NULL,
    [ResourceDescription] nvarchar(max) NOT NULL,
    [OrchestrationId] [nvarchar](50) NULL,
    [OrchestrationExecutionId] [nvarchar](50) NULL,
    [OrchestrationLockTime] [datetime2](7) NULL,
    [OrchestrationInput] [nvarchar](max) NULL,
    [ETag] timestamp NULL,
    [CreatedTime] datetime2(7) NOT NULL,
    [LastUpdatedTime] datetime2(7) NOT NULL,
    [Region] nvarchar(50) default(null),
    [SkuName] nvarchar(20) default(null),
    CONSTRAINT [PK__ProvisioningService__3214EC07525481E1] PRIMARY KEY CLUSTERED 
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
) ON [PRIMARY]
ALTER TABLE [ProvisioningServicesTable]  WITH CHECK ADD 
	CONSTRAINT [FK_ProvisioningServicesTable_UserSubscriptionsTable] FOREIGN KEY([UserSubscriptionsTableId]) REFERENCES [UserSubscriptionsTable] ([Id])

ALTER TABLE [ProvisioningServicesTable] CHECK CONSTRAINT [FK_ProvisioningServicesTable_UserSubscriptionsTable]
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = N'NCIX_ProvisioningServicesTable_ProvisioningServiceName')
BEGIN
CREATE UNIQUE NONCLUSTERED INDEX [NCIX_ProvisioningServicesTable_ProvisioningServiceName] ON [ProvisioningServicesTable]
(
    [ProvisioningServiceName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END

-- TODO: After [NCIX_ProvisioningServicesTable_ResourceGroup_UserSubscriptionsTableId] is created this Index can be dropped
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = N'NCIX_ProvisioningServicesTable_ResourceGroup')
BEGIN
CREATE NONCLUSTERED INDEX [NCIX_ProvisioningServicesTable_ResourceGroup] ON [ProvisioningServicesTable]
(
    [ResourceGroup] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END

-- TODO: After [NCIX_ProvisioningServicesTable_UserSubscriptionsTableId_Id] is created this Index can be dropped
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = N'NCIX_ProvisioningServicesTable_UserSubscriptionsTableId') 
BEGIN
CREATE NONCLUSTERED INDEX NCIX_ProvisioningServicesTable_UserSubscriptionsTableId ON dbo.ProvisioningServicesTable (UserSubscriptionsTableId); 
END
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'Region' AND OBJECT_ID = OBJECT_ID(N'[ProvisioningServicesTable]'))
BEGIN
ALTER TABLE [dbo].[ProvisioningServicesTable] ADD [Region] [nvarchar](50) DEFAULT(NULL)
END

IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'SkuName' AND OBJECT_ID = OBJECT_ID(N'[ProvisioningServicesTable]'))
BEGIN
ALTER TABLE [dbo].[ProvisioningServicesTable] ADD [SkuName] [nvarchar](20) DEFAULT(NULL)
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = N'NCIX_ProvisioningServicesTable_UserSubscriptionsTableId_Id')
BEGIN
CREATE NONCLUSTERED INDEX [NCIX_ProvisioningServicesTable_UserSubscriptionsTableId_Id] ON [dbo].[ProvisioningServicesTable]
(
	[UserSubscriptionsTableId] ASC,
  [Id] ASC
)
INCLUDE ([State])
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = N'NCIX_ProvisioningServicesTable_ResourceGroup_UserSubscriptionsTableId')
BEGIN
CREATE NONCLUSTERED INDEX [NCIX_ProvisioningServicesTable_ResourceGroup_UserSubscriptionsTableId] ON [dbo].[ProvisioningServicesTable]
(
	[ResourceGroup] ASC,
  [UserSubscriptionsTableId] ASC
)
INCLUDE ([State])
END

IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = N'NCIX_ProvisioningServicesTable_LastUpdatedTime')
BEGIN
CREATE NONCLUSTERED INDEX NCIX_ProvisioningServicesTable_LastUpdatedTime ON dbo.ProvisioningServicesTable (LastUpdatedTime)
INCLUDE ([State])
END

-- ProvisioningServiceCertificatesTable
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ProvisioningServiceCertificatesTable]') AND type in (N'U'))
BEGIN
	CREATE TABLE [ProvisioningServiceCertificatesTable](
		[ProvisioningServiceId] int NOT NULL,
		[Name] [nvarchar](256) NOT NULL,
		[RawBytes] varbinary(MAX) NOT NULL,
		[IsVerified] bit NOT NULL,
		[Purpose] INT NULL,
		[HasPrivateKey] bit NOT NULL,
		[Nonce] nvarchar(100) NULL,
		[ETag] RowVersion NOT NULL,
		[Created] DateTime NOT NULL,
		[LastUpdated] DateTime NOT NULL
		CONSTRAINT [PK_ProvisioningServiceCertificatesTable] PRIMARY KEY CLUSTERED
		(
			[ProvisioningServiceId] ASC,
			[Name] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
	) ON [PRIMARY]

	ALTER TABLE [ProvisioningServiceCertificatesTable]  WITH CHECK ADD CONSTRAINT [FK_ProvisioningServiceCertificatesTable_ProvisioningServicesTable] FOREIGN KEY([ProvisioningServiceId])
	REFERENCES [ProvisioningServicesTable] ([Id]) ON DELETE CASCADE

	ALTER TABLE [ProvisioningServiceCertificatesTable] ADD CONSTRAINT DF_ProvisioningServiceCertificatesTable_Created DEFAULT GETUTCDATE() FOR [Created]
	
END
GO
