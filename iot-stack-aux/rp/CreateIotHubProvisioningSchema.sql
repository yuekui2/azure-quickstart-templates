--//----------------------------------------------------------------
--// Copyright (c) Microsoft Corporation.  All rights reserved.
--//----------------------------------------------------------------

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- VersionTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[VersionTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [VersionTable]
    (
        [Major] [int] NOT NULL,
        [Minor] [int] NOT NULL,
        [Build] [int] NOT NULL,
        [Revision] [int] NOT NULL,
        [LastUpdated] [datetime2](7) NOT NULL,
        PRIMARY KEY CLUSTERED ([Major], [Minor], [Build], [Revision])
    )
END
GO

-- UserSubscriptionsTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[UserSubscriptionsTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [UserSubscriptionsTable]
    (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [SubscriptionId] [nvarchar](100) NOT NULL UNIQUE,
        [State] nvarchar(50) NOT NULL,
        -- 1 (Registered), 2 (Unregistered), 3 (Suspended), 4 (Deleted), 5 (Warned)
        [RegistrationDate] datetime2(7) NOT NULL,
        [Properties] nvarchar(max),
        [InternalProperties] nvarchar(max)
            CONSTRAINT [PK__UserSubs__3214EC07504F2A78] PRIMARY KEY CLUSTERED
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
END

-- TODO : Once [NCIX_UserSubscriptionsTable_SubscriptionId_Id] has been created this Index can be dropped
IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_UserSubscriptionsTable_SubscriptionId')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX NCIX_UserSubscriptionsTable_SubscriptionId ON dbo.UserSubscriptionsTable (SubscriptionId);
END
GO

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_UserSubscriptionsTable_SubscriptionId_Id')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [NCIX_UserSubscriptionsTable_SubscriptionId_Id] ON [dbo].[UserSubscriptionsTable]
(
	[SubscriptionId] ASC,
  [Id] ASC
)
END
GO

-- ElasticPoolsTable
-- TODO: This statement to remove the IotHubScaleConfigurations column can be removed after it has been successfully deployed
IF EXISTS (SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[ElasticPoolsTable]')) AND
    EXISTS(SELECT *
    FROM sys.columns
    WHERE Name = N'IotHubScaleConfigurations' AND OBJECT_ID = OBJECT_ID(N'[ElasticPoolsTable]'))
BEGIN
    ALTER TABLE [ElasticPoolsTable]
DROP COLUMN [IotHubScaleConfigurations]
END
GO

IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[ElasticPoolsTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [ElasticPoolsTable]
    (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [ElasticPoolName] [nvarchar](63) NOT NULL UNIQUE,
        -- Max DNS part length is 63
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
        [SkuUnits] int default(0),
        CONSTRAINT [PK__IotHub__3214EC07525256E9] PRIMARY KEY CLUSTERED
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
    ALTER TABLE [ElasticPoolsTable]  WITH CHECK ADD CONSTRAINT [FK_ElasticPoolsTable_UserSubscriptionsTable] FOREIGN KEY([UserSubscriptionsTableId])
REFERENCES [UserSubscriptionsTable] ([Id])
    ALTER TABLE [ElasticPoolsTable] CHECK CONSTRAINT [FK_ElasticPoolsTable_UserSubscriptionsTable]
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_ElasticPoolsTable_ElasticPoolName')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [NCIX_ElasticPoolsTable_ElasticPoolName] ON [ElasticPoolsTable]
(
    [ElasticPoolName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_ElasticPoolsTable_UserSubscriptionsTableId_Id')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_ElasticPoolsTable_UserSubscriptionsTableId_Id] ON [dbo].[ElasticPoolsTable]
(
	[UserSubscriptionsTableId] ASC,
  [Id] ASC
)
INCLUDE ([State])
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_ElasticPoolsTable_ResourceGroup_UserSubscriptionsTableId')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_ElasticPoolsTable_ResourceGroup_UserSubscriptionsTableId] ON [dbo].[ElasticPoolsTable]
(
	[ResourceGroup] ASC,
  [UserSubscriptionsTableId] ASC
)
INCLUDE ([State])
END

-- IotHubsTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[IotHubsTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [IotHubsTable]
    (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [IotHubName] [nvarchar](63) NOT NULL UNIQUE,
        -- Max DNS part length is 63
        [ResourceGroup] [nvarchar](128) NOT NULL,
        [UserSubscriptionsTableId] [int] NOT NULL,
        [State] [nvarchar](50) NOT NULL,
        [ResourceDescription] nvarchar(max) NOT NULL,
        [RoutingProperties] nvarchar(max) default(NULL),
        [ReplicaInfo] nvarchar(max) default(NULL),
        [OrchestrationId] [nvarchar](50) NULL,
        [OrchestrationExecutionId] [nvarchar](50) NULL,
        [OrchestrationLockTime] [datetime2](7) NULL,
        [OrchestrationInput] [nvarchar](max) NULL,
        [ETag] timestamp NULL,
        [CreatedTime] datetime2(7) NOT NULL,
        [LastUpdatedTime] datetime2(7) NOT NULL,
        [Region] nvarchar(50) default(null),
        [SkuName] nvarchar(20) default(null),
        [SkuUnits] int default(0),
        [ElasticPoolId] int NULL,
        CONSTRAINT [PK__IotHub__3214EC07525481E1] PRIMARY KEY CLUSTERED
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
    ALTER TABLE [IotHubsTable]  WITH CHECK ADD
	CONSTRAINT [FK_IotHubsTable_UserSubscriptionsTable] FOREIGN KEY([UserSubscriptionsTableId]) REFERENCES [UserSubscriptionsTable] ([Id]),
	CONSTRAINT [FK_IotHubsTable_ElasticPoolsTable] FOREIGN KEY([ElasticPoolId]) REFERENCES [ElasticPoolsTable] ([Id])
    ALTER TABLE [IotHubsTable] CHECK CONSTRAINT [FK_IotHubsTable_UserSubscriptionsTable]
    ALTER TABLE [IotHubsTable] CHECK CONSTRAINT [FK_IotHubsTable_ElasticPoolsTable]
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubsTable_IotHubName')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [NCIX_IotHubsTable_IotHubName] ON [IotHubsTable]
(
    [IotHubName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END

-- TODO: After [NCIX_IotHubsTable_ResourceGroup_UserSubscriptionsTableId] is created this Index can be dropped
IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubsTable_ResourceGroup')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_IotHubsTable_ResourceGroup] ON [IotHubsTable]
(
    [ResourceGroup] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END

-- TODO: After [NCIX_IotHubsTable_UserSubscriptionsTableId_Id] is created this Index can be dropped
IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_IotHubsTable_UserSubscriptionsTableId')
BEGIN
    CREATE NONCLUSTERED INDEX NCIX_IotHubsTable_UserSubscriptionsTableId ON dbo.IotHubsTable (UserSubscriptionsTableId);
END
GO

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'RoutingProperties' AND OBJECT_ID = OBJECT_ID(N'[IotHubsTable]'))
BEGIN
    ALTER TABLE [dbo].[IotHubsTable] ADD [RoutingProperties] [nvarchar](max) DEFAULT(NULL)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'ReplicaInfo' AND OBJECT_ID = OBJECT_ID(N'[IotHubsTable]'))
BEGIN
    ALTER TABLE [dbo].[IotHubsTable] ADD [ReplicaInfo] [nvarchar](max) DEFAULT(NULL)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'Region' AND OBJECT_ID = OBJECT_ID(N'[IotHubsTable]'))
BEGIN
    ALTER TABLE [dbo].[IotHubsTable] ADD [Region] [nvarchar](50) DEFAULT(NULL)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'SkuName' AND OBJECT_ID = OBJECT_ID(N'[IotHubsTable]'))
BEGIN
    ALTER TABLE [dbo].[IotHubsTable] ADD [SkuName] [nvarchar](20) DEFAULT(NULL)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'SkuUnits' AND OBJECT_ID = OBJECT_ID(N'[IotHubsTable]'))
BEGIN
    ALTER TABLE [dbo].[IotHubsTable] ADD [SkuUnits] [int] DEFAULT(0)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'ElasticPoolId' AND OBJECT_ID = OBJECT_ID(N'[IotHubsTable]'))
BEGIN
    ALTER TABLE [dbo].[IotHubsTable] ADD
  [ElasticPoolId] [int] DEFAULT(NULL)
  CONSTRAINT [FK_IotHubsTable_ElasticPoolsTable] FOREIGN KEY([ElasticPoolId]) REFERENCES [ElasticPoolsTable] ([Id])
    ALTER TABLE [IotHubsTable] CHECK CONSTRAINT [FK_IotHubsTable_ElasticPoolsTable]
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubsTable_UserSubscriptionsTableId_Id')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_IotHubsTable_UserSubscriptionsTableId_Id] ON [dbo].[IotHubsTable]
(
	[UserSubscriptionsTableId] ASC,
  [Id] ASC
)
INCLUDE ([State])
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubsTable_ResourceGroup_UserSubscriptionsTableId')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_IotHubsTable_ResourceGroup_UserSubscriptionsTableId] ON [dbo].[IotHubsTable]
(
	[ResourceGroup] ASC,
  [UserSubscriptionsTableId] ASC
)
INCLUDE ([State])
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubsTable_ElasticPoolId_Id')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_IotHubsTable_ElasticPoolId_Id] ON [dbo].[IotHubsTable]
(
	[ElasticPoolId] ASC,
  [Id] ASC
)
INCLUDE ([State])
END

-- IotHubScalePropertiesTable no longer needed.  Can remove this statement after deployment.
IF EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[IotHubScalePropertiesTable]') AND type in (N'U'))
BEGIN
    DROP TABLE [IotHubScalePropertiesTable]
END
GO

-- InternalSubscriptionTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[InternalSubscriptionsTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [InternalSubscriptionsTable]
    (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [SubscriptionId] [nvarchar](100) NOT NULL UNIQUE,
        [MaxServiceBusNamespaces] [int] NOT NULL,
        [MaxStorageAccounts] [int] NOT NULL,
        [MaxCores] [int] NOT NULL,
        [AvailableServiceBusNamespaces] [int] NOT NULL,
        [AvailableStorageAccounts] [int] NOT NULL,
        [AvailableCores] [int] NOT NULL,
        [ETag] timestamp NULL,
        CONSTRAINT [PK_InternalSubscriptionsTable] PRIMARY KEY CLUSTERED
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
END

-- ResourcePoolTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[ResourcePoolsTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [ResourcePoolsTable]
    (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [PoolType] [nvarchar](50) NOT NULL,
        [Region] [nvarchar](50) NOT NULL,
        [MaxCapacity] [int] NOT NULL,
        [AvailableCapacity] [int] NOT NULL,
        [MetaData] [nvarchar](max) NOT NULL,
        [State] [nvarchar](50) NOT NULL,
        [Name] [nvarchar](50) NOT NULL UNIQUE,
        [InternalSubscriptionsTableId] [int] NOT NULL,
        [Capabilities] [bigint] NOT NULL DEFAULT 0,
        [ResourcePoolOwnerType] nvarchar(50) NOT NULL DEFAULT('System'),
        [ResourceOwnerId] [int] NOT NULL DEFAULT 0,
        CONSTRAINT [PK_ResourcePoolsTable] PRIMARY KEY CLUSTERED
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
    ALTER TABLE [ResourcePoolsTable]  WITH CHECK ADD CONSTRAINT [FK_ResourcePoolsTable_InternalSubscriptionsTable] FOREIGN KEY([InternalSubscriptionsTableId])
REFERENCES [InternalSubscriptionsTable] ([Id])
    ALTER TABLE [ResourcePoolsTable] CHECK CONSTRAINT [FK_ResourcePoolsTable_InternalSubscriptionsTable]
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'Capabilities' AND OBJECT_ID = OBJECT_ID(N'[ResourcePoolsTable]'))
BEGIN
    ALTER TABLE [dbo].[ResourcePoolsTable] ADD [Capabilities] [bigint] NOT NULL DEFAULT 0
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'ResourcePoolOwnerType' AND OBJECT_ID = OBJECT_ID(N'[ResourcePoolsTable]'))
BEGIN
    ALTER TABLE [dbo].[ResourcePoolsTable] ADD [ResourcePoolOwnerType] nvarchar(50) NOT NULL DEFAULT('System')
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'ResourceOwnerId' AND OBJECT_ID = OBJECT_ID(N'[ResourcePoolsTable]'))
BEGIN
    ALTER TABLE [dbo].[ResourcePoolsTable] ADD [ResourceOwnerId] [int] NOT NULL DEFAULT 0
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_ResourcePoolsTable')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_ResourcePoolsTable] ON [ResourcePoolsTable]
(
    [PoolType] ASC,
    [Region] ASC,
    [AvailableCapacity] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_ResourcePoolsTable_ResourceOwner')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_ResourcePoolsTable_ResourceOwner] ON [ResourcePoolsTable]
(
    [PoolType] ASC,
    [Region] ASC,
    [AvailableCapacity] DESC,
    [ResourcePoolOwnerType] ASC,
    [ResourceOwnerId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourcePoolsTable_PoolType')
BEGIN
    CREATE NONCLUSTERED INDEX NCIX_ResourcePoolsTable_PoolType ON dbo.ResourcePoolsTable (PoolType);
END
GO

-- ResourceAllocationTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[ResourceAllocationsTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [ResourceAllocationsTable]
    (
        [ResourcePoolId] [int] NOT NULL,
        [ResourceName] [nvarchar](100) NOT NULL UNIQUE,
        [IotHubId] [int] NULL,
        [State] nvarchar(50) NOT NULL,
        [ETag] timestamp NULL,
        [CreatedTime] datetime2(7) NOT NULL,
        [LastUpdatedTime] datetime2(7) NOT NULL,
        [ExpiryTime] datetime2(7) NULL,
        [Metadata] nvarchar(max) NULL,
        [ResourceOwnerType] nvarchar(50) NOT NULL DEFAULT('IotHub'),
        CONSTRAINT [PK_ResourceAllocationTable] PRIMARY KEY CLUSTERED
    (
        [ResourceName] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
    ALTER TABLE [ResourceAllocationsTable]  WITH CHECK ADD CONSTRAINT [FK_ResourceAllocationsTable_ResourcePoolsTable] FOREIGN KEY([ResourcePoolId])
REFERENCES [ResourcePoolsTable] ([Id])
    ALTER TABLE [dbo].[ResourceAllocationsTable] CHECK CONSTRAINT [FK_ResourceAllocationsTable_ResourcePoolsTable]
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'Metadata' AND OBJECT_ID = OBJECT_ID(N'[ResourceAllocationsTable]'))
BEGIN
    ALTER TABLE [dbo].[ResourceAllocationsTable] ADD [Metadata] nvarchar(max)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'ResourceOwnerType' AND OBJECT_ID = OBJECT_ID(N'[ResourceAllocationsTable]'))
BEGIN
    ALTER TABLE [dbo].[ResourceAllocationsTable] ADD [ResourceOwnerType] [nvarchar](50) NOT NULL DEFAULT 'IotHub'
END

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourceAllocationsTable_IotHubId')
BEGIN
    CREATE NONCLUSTERED INDEX NCIX_ResourceAllocationsTable_IotHubId ON dbo.ResourceAllocationsTable (IotHubId);
END
GO

-- After NCIX_ResourceAllocationsTable_ResourcePoolId_IotHubId has been rolled out, this index can be dropped
IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourceAllocationsTable_ResourcePoolId')
BEGIN
    CREATE NONCLUSTERED INDEX NCIX_ResourceAllocationsTable_ResourcePoolId ON dbo.ResourceAllocationsTable (ResourcePoolId);
END
GO

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourceAllocationsTable_ExpiryTime')
BEGIN
    CREATE NONCLUSTERED INDEX NCIX_ResourceAllocationsTable_ExpiryTime ON dbo.ResourceAllocationsTable (ExpiryTime);
END
GO

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourceAllocationsTable_State')
BEGIN
    CREATE NONCLUSTERED INDEX NCIX_ResourceAllocationsTable_State ON dbo.ResourceAllocationsTable ([State]);
END
GO

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourceAllocationsTable_ResourcePoolId_IotHubId')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_ResourceAllocationsTable_ResourcePoolId_IotHubId] ON [dbo].[ResourceAllocationsTable]
(
    [ResourcePoolId] ASC, [IotHubId] ASC
)
INCLUDE ([State],[ETag],[CreatedTime],[LastUpdatedTime],[ExpiryTime])
END
GO

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourceAllocationsTable_ResourcePoolId_IotHubId_ResourceOwnerType')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_ResourceAllocationsTable_ResourcePoolId_IotHubId_ResourceOwnerType] ON [dbo].[ResourceAllocationsTable]
(
    [ResourcePoolId] ASC, [IotHubId] ASC, [ResourceOwnerType] ASC
)
INCLUDE ([State],[ETag],[CreatedTime],[LastUpdatedTime],[ExpiryTime])
END
GO

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourceAllocationsTable_ResourcePoolId_State')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_ResourceAllocationsTable_ResourcePoolId_State] ON [dbo].[ResourceAllocationsTable]
(
    [ResourcePoolId] ASC, [State] ASC
)
INCLUDE ([IotHubId],[ETag],[CreatedTime],[LastUpdatedTime],[ExpiryTime])
END
GO

IF NOT EXISTS (SELECT name
FROM sys.indexes
WHERE name = N'NCIX_ResourceAllocationsTable_ResourcePoolId_State_ResourceOwnerType')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_ResourceAllocationsTable_ResourcePoolId_State_ResourceOwnerType] ON [dbo].[ResourceAllocationsTable]
(
    [ResourcePoolId] ASC, [State] ASC
)
INCLUDE ([IotHubId],[ETag],[CreatedTime],[LastUpdatedTime],[ExpiryTime],[ResourceOwnerType])
END
GO

-- Configuration table
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[ConfigurationTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [ConfigurationTable]
    (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [ScopeKey] [int] NOT NULL,
        [ScopeValue] [nvarchar](128) NULL,
        [Configurations] nvarchar(MAX) NOT NULL,
        [OrchestrationId] [nvarchar](50) NULL,
        [ExecutionId] [nvarchar](50) NULL,
        [OrchestrationLockTime] [datetime2](7) NULL,
        [ETag] timestamp NULL,
        CONSTRAINT [PK_ConfigurationTable] PRIMARY KEY CLUSTERED
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_ScopeKey_ScopeValue')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [NCIX_ScopeKey_ScopeValue] ON [ConfigurationTable]
(
    [ScopeKey] ASC,
    [ScopeValue] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'OrchestrationId' AND OBJECT_ID = OBJECT_ID(N'[ConfigurationTable]'))
BEGIN
    ALTER TABLE [dbo].[ConfigurationTable] ADD [OrchestrationId] [nvarchar](50) DEFAULT(NULL)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'ExecutionId' AND OBJECT_ID = OBJECT_ID(N'[ConfigurationTable]'))
BEGIN
    ALTER TABLE [dbo].[ConfigurationTable] ADD [ExecutionId] [nvarchar](50) DEFAULT(NULL)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'OrchestrationLockTime' AND OBJECT_ID = OBJECT_ID(N'[ConfigurationTable]'))
BEGIN
    ALTER TABLE [dbo].[ConfigurationTable] ADD [OrchestrationLockTime] [datetime2](7) DEFAULT(NULL)
END

IF NOT EXISTS(SELECT *
FROM sys.columns
WHERE Name = N'ETag' AND OBJECT_ID = OBJECT_ID(N'[ConfigurationTable]'))
BEGIN
    ALTER TABLE [dbo].[ConfigurationTable] ADD [ETag] timestamp
END

-- IoT Hub Events Table
-- Tracks events that mainly impact billing.
-- This is not an operation log for all operations in the IotHub service
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[IotHubEventsTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [IotHubEventsTable]
    (
        [Id] [bigint] IDENTITY(1,1) NOT NULL,
        [IotHubId] [int] NOT NULL,
        [EventEmissionTime] datetime2(7) NOT NULL,
        -- The UTC time when this event is being written to the DB
        [EventOccurrenceTime] datetime2(7) NOT NULL,
        -- The UTC time when this event actually occurred.
        [EventType] int NOT NULL,
        -- ( 1 StateChanged | 2 ProvisionedCapacityChanged | 3 BillingEventEmitted )
        [EventDetail1] nvarchar(200) NULL,
        [EventDetail2] nvarchar(400) NULL,
        CONSTRAINT [PK_IotHubEventsTable] PRIMARY KEY CLUSTERED
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
END

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubEventsTable_IotHubId_EventType_EventOccurrenceTime')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_IotHubEventsTable_IotHubId_EventType_EventOccurrenceTime] ON [IotHubEventsTable] ([IotHubId], [EventType], [EventOccurrenceTime])
END
GO

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_WI_IotHubEventsTable_EventType_EventDetail1')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_WI_IotHubEventsTable_EventType_EventDetail1] ON [dbo].[IotHubEventsTable] ([EventType], [EventDetail1]) INCLUDE ([EventDetail2], [EventOccurrenceTime], [IotHubId])
END
GO

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubEventsTable_IotHubId_EventOccurrenceTime')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_IotHubEventsTable_IotHubId_EventOccurrenceTime] ON [IotHubEventsTable] ([IotHubId], [EventOccurrenceTime])
END
GO

-- @ShSama We can drop this index since we added NCIX_WI_IotHubEventsTable_EventType_EventDetail1 above
IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubEventsTable_EventType_EventDetail1')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_IotHubEventsTable_EventType_EventDetail1] ON [IotHubEventsTable] ([EventType], [EventDetail1])
END
GO

IF NOT EXISTS (SELECT *
FROM sys.indexes
WHERE name = N'NCIX_IotHubEventsTable_EventType_EventDetail2')
BEGIN
    CREATE NONCLUSTERED INDEX [NCIX_IotHubEventsTable_EventType_EventDetail2] ON [IotHubEventsTable] ([EventType], [EventDetail2])
END
GO

-- FeatureFiltersTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[FeatureFiltersTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [FeatureFiltersTable]
    (
        [FeatureIdentifier] [nvarchar](100) NOT NULL,
        [IotHubFeatureFilter] nvarchar(MAX) NOT NULL,
        CONSTRAINT [PK_FeatureFiltersTable] PRIMARY KEY CLUSTERED
    (
        [FeatureIdentifier] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]
END
GO

-- CertificatesTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[CertificatesTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [CertificatesTable]
    (
        [IotHubId] int NOT NULL,
        [Name] [nvarchar](256) NOT NULL,
        [RawBytes] varbinary(MAX) NOT NULL,
        [IsVerified] bit NOT NULL,
        [Purpose] INT NULL,
        [HasPrivateKey] bit NOT NULL,
        [Nonce] nvarchar(100) NULL,
        [ETag] RowVersion NOT NULL,
        [Created] DateTime NOT NULL,
        [LastUpdated] DateTime NOT NULL
            CONSTRAINT [PK_CertificatesTable] PRIMARY KEY CLUSTERED
		(
			[IotHubId] ASC,
			[Name] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]

    ALTER TABLE [CertificatesTable]  WITH CHECK ADD CONSTRAINT [FK_CertificatesTable_IotHubsTable] FOREIGN KEY([IotHubId])
	REFERENCES [IotHubsTable] ([Id]) ON DELETE CASCADE

    ALTER TABLE [CertificatesTable] ADD CONSTRAINT DF_CertificatesTable_Created DEFAULT GETUTCDATE() FOR [Created]

END
GO

-- EventGridSubscriptionsTable
IF NOT EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[EventGridSubscriptionsTable]') AND type in (N'U'))
BEGIN
    CREATE TABLE [EventGridSubscriptionsTable]
    (
        [IotHubId] int NOT NULL,
        [ETag] RowVersion NOT NULL,
        [EventGridSubscriptionName] nvarchar(256) NOT NULL,
        [EventGridSubscription] nvarchar(max) NULL,
        CONSTRAINT [PK_EventGridSubscriptionsTable] PRIMARY KEY CLUSTERED
		(
			[IotHubId] ASC,
			[EventGridSubscriptionName] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ) ON [PRIMARY]

    ALTER TABLE [EventGridSubscriptionsTable]  WITH CHECK ADD CONSTRAINT [FK_EventGridSubscriptionsTable_IotHubsTable] FOREIGN KEY([IotHubId])
	REFERENCES [IotHubsTable] ([Id]) ON DELETE CASCADE
END
GO