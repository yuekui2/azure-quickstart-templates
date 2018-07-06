--//----------------------------------------------------------------
--// Copyright (c) Microsoft Corporation.  All rights reserved.
--//----------------------------------------------------------------

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

UPDATE [ResourceAllocationsTable] SET ExpiryTime = DATEADD(MINUTE,60,CreatedTime) WHERE ExpiryTime IS NULL AND State != 'Committed'

-- These updates are being done as a result of a state collapsing exercise.
-- The Importing, Exporting, Updating and Upgrading states are being replaced with Transitioning
-- The MarkedForDeletion state is being removed
-- The Created state is being removed
 
--UPDATE [IotHubsTable] SET State = 'Transitioning' WHERE State IN ('Importing', 'Exporting', 'Updating', 'Upgrading');
--UPDATE [IotHubsTable] SET State = 'Deleting' WHERE State = 'MarkedForDeletion';
--UPDATE [IotHubsTable] SET State = 'Activating' WHERE State = 'Created';

-- ScaleUnit and NamespaceSubscriptionId are System pools
-- All other non-ElasticPools and non-DPS pools are IotHub pools
UPDATE [ResourcePoolsTable] SET [ResourcePoolOwnerType] = 'System' where ([PoolType] = 'NamespaceSubscriptionId' or [PoolType] = 'ScaleUnit') and [ResourcePoolOwnerType] != 'IotDps'
UPDATE [ResourcePoolsTable] SET [ResourcePoolOwnerType] = 'IotHub' where [ResourcePoolOwnerType] != 'ElasticPool'and [ResourcePoolOwnerType] != 'IotDps' and [PoolType] != 'NamespaceSubscriptionId' and [PoolType] != 'ScaleUnit'

GO
