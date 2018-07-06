--//----------------------------------------------------------------
--// Copyright (c) Microsoft Corporation.  All rights reserved.
--//----------------------------------------------------------------

set ansi_nulls on
set quoted_identifier on
set nocount on
go

-- Global Return Error Codes. For Certificates and EventGrid look at the corresponding Sql{}Datastore.cs 
-- 0 : OK
-- 1 : Invalid ETag
-- 2 : Duplicate user subscriptions
-- 3 : User subscription doesn't exist
-- 4 : Duplicate IotHub name
-- 5 : IotHub name doesn't exist
-- 6 : InternalSubscription has resources allocated in Resource pool
-- 7 : InternalSubscription was not found
-- 8 : Duplicate Resource pool name
-- 9 : Resource pool doesn't exist
-- 10: ResourcePool has resources allocated in Resource Allocation table
-- 11: Duplicate Resource Allocation name
-- 12: Resource allocation doesn't exist
-- 13: IotHubTable has resources allocated in Resource Allocation table
-- 14: No available capacity found in Resource Pool
-- 15: Failed to update Resource Pool availability
-- 16: Orchestration lock lost
-- 17: Object locked by another Orchestration
-- 18: Resource pool doesn't exist or invalid MaxCapacity specified
-- 19: Error inserting IotHubEvents
-- 20: No IotHubEvents with the provided partitionkey were found
-- 21: Invalid parameters for row creation
-- 22: Clear lock failed
---------------------------------
-- SubscriptionsTable CRUD
---------------------------------

IF TYPE_ID(N'IotHubEventsTableTypeV1') IS NULL
BEGIN
CREATE TYPE [IotHubEventsTableTypeV1] AS TABLE (
    [IotHubId] int NOT NULL, 
    [EventOccurrenceTime] datetime2(7) NOT NULL,
    [EventType] int NOT NULL,
	[EventDetail1] nvarchar(200) NULL,
	[EventDetail2] nvarchar(400) NULL)
END
GO

if exists (select * from sys.objects where object_id = object_id(N'[CreateOrUpdateUserSubscriptionV1]') and type in (N'P', N'PC'))
	drop procedure [CreateOrUpdateUserSubscriptionV1]
go
create procedure [CreateOrUpdateUserSubscriptionV1]
    @subscriptionId nvarchar(100),	
    @state nvarchar(50),
	@registrationDate datetime2,
	@properties nvarchar(max) = NULL
as
begin
	-- try update first
    update [UserSubscriptionsTable] 
    set 
        [RegistrationDate] = @registrationDate,
        [State] = @state,
		[Properties] = @properties
    where
        [SubscriptionId] = @subscriptionId

	-- if not updated, create new entry
	if (@@rowcount = 0)
		insert into [UserSubscriptionsTable] ([SubscriptionId], [RegistrationDate], [State], [Properties])
		values(@subscriptionId, @RegistrationDate, @state, @properties)

	select 0 as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateUserSubscriptionInternalPropertiesV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateUserSubscriptionInternalPropertiesV1]
go
create procedure [UpdateUserSubscriptionInternalPropertiesV1]
    @subscriptionId nvarchar(100),	
	@internalProperties nvarchar(max) = NULL
as
begin
	declare @result int = 0
    update [UserSubscriptionsTable] 
    set 
        [InternalProperties] = @internalProperties
    where
        [SubscriptionId] = @subscriptionId

		if (@@rowcount = 0)
		set @result = 3 -- 3: UserSubscriptionDoesntExist
	
	select @result as 'Result'	
end
go


if exists (select * from sys.objects where object_id = object_id(N'[GetUserSubscriptionV1]') and type in (N'P', N'PC'))
	drop procedure [GetUserSubscriptionV1]
go
create procedure [GetUserSubscriptionV1]
	@subscriptionId nvarchar(50) = NULL
as
begin

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select [SubscriptionId], [RegistrationDate], [State], [Properties], [InternalProperties]
	from [UserSubscriptionsTable]'

	if @subscriptionId is not null      select @sql += @cond + N'[SubscriptionId] = @subscriptionId ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@subscriptionId nvarchar(100) = null', 
		@subscriptionId

end
go

---------------------------------
-- Resource Allocation CRUD
---------------------------------

if exists (select * from sys.objects where object_id = object_id(N'[UpdateAllocatedResourceV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateAllocatedResourceV1]
go
create procedure [UpdateAllocatedResourceV1]
	@resourceName nvarchar(100),
	@iotHubId int = null,
	@state nvarchar(50) = null,
	@lastUpdatedTime datetime2 = null
as
begin
	declare @result int = 0
	if @lastUpdatedTime is null set @lastUpdatedTime  = GetUtcDate()

	update [ResourceAllocationsTable] 
	set 
		[ResourceName] = @resourceName,
		[LastUpdatedTime] = @lastUpdatedTime,
		[IotHubId] = CASE WHEN @iotHubId is null THEN [IotHubId] ELSE @iotHubId END,
		[State] = CASE WHEN @state is null THEN [State] ELSE @state END
	where
		[ResourceName] = @resourceName

	if (@@rowcount = 0)
		set @result = 12 -- 12: Resource allocation doesn't exist
	
	select @result as 'Result'	
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateAllocatedResourceV2]') and type in (N'P', N'PC'))
	drop procedure [UpdateAllocatedResourceV2]
go
create procedure [UpdateAllocatedResourceV2]
	@resourceName nvarchar(100),
	@resourceOwnerType nvarchar(50) = null,
	@resourceOwnerId int = null,
	@state nvarchar(50) = null,
	@lastUpdatedTime datetime2 = null
as
begin
	declare @result int = 0
	if @lastUpdatedTime is null set @lastUpdatedTime  = GetUtcDate()

	update [ResourceAllocationsTable] 
	set 
		[ResourceName] = @resourceName,
		[LastUpdatedTime] = @lastUpdatedTime,
		[ResourceOwnerType] = CASE WHEN @resourceOwnerType is null THEN [ResourceOwnerType] ELSE @resourceOwnerType END,
		[IotHubId] = CASE WHEN @resourceOwnerId is null THEN [IotHubId] ELSE @resourceOwnerId END,
		[State] = CASE WHEN @state is null THEN [State] ELSE @state END
	where
		[ResourceName] = @resourceName

	if (@@rowcount = 0)
		set @result = 12 -- 12: Resource allocation doesn't exist
	
	select @result as 'Result'	
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateAllocatedResourcesStateV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateAllocatedResourcesStateV1]
go
create procedure [UpdateAllocatedResourcesStateV1]
	@iotHubId int,
	@oldState nvarchar(50),
	@newState nvarchar(50),	
	@lastUpdatedTime datetime2 = null,
	@resourceName nvarchar(100) = null,
	@resourceExpirationBufferInSeconds int = 0
as
begin
	declare @result int = 0
	declare @expiryTime datetime

	if @lastUpdatedTime is null set @lastUpdatedTime  = GetUtcDate()
	
	-- Only 2 final transition states are possible currently so expiry times will be set only for these 2 known transitions during update
	-- When the new state is Deleting, the oldState check is removed because all three states Allocated, Committed and Created can move to Deleting
			
	-- Need to mark allocated resources to desired state
	update [ResourceAllocationsTable] 
	set 
		[LastUpdatedTime] = @lastUpdatedTime,				
		[ExpiryTime] = case 							
							-- Do not overwrite the expiry time for a resource that was already in the deleting state or if it is a retry
							when ([ResourceAllocationsTable].[State] = 'Deleting' or @newState = @oldState) 
								then [ExpiryTime] 
							-- On Deleting, compute resources must expire immediately (without any expiration buffer)
							when (@newState = 'Deleting' and [PoolType] = 'ScaleUnit')
								then GetUtcDate()
							-- On Deleting, non-compute resources are marked with an expiration buffer to handle in-flight requests to the resource while waiting for compute to shut down
							when (@newState = 'Deleting' or @newState = 'Restoring')
								then DateAdd(second, @resourceExpirationBufferInSeconds, GetUtcDate())
							-- Only Committed newState is currently possible at this point.  We wipe the ExpiryTime when commiting the resource.
							else null 
						end,
		[State] = @newState
	from
		[ResourceAllocationsTable]
		join [ResourcePoolsTable]
		on  [ResourceAllocationsTable].[ResourcePoolId] = [ResourcePoolsTable].[Id]
	where
		[ResourceOwnerType] = 'IotHub' and 
		[IotHubId] = @iotHubId and 
		(@newState = @oldState or (@newState = 'Deleting' and  (@oldState is null or @oldState = '')) or [ResourceAllocationsTable].[State] = @oldState or [ResourceAllocationsTable].[State] = @newState) and
		(@resourceName is null or [ResourceName] = @resourceName)

	if (@newState != 'Deleting' and @@rowcount = 0)
		set @result = 12 -- 12: Resource allocation doesn't exist. If we are attempting to move to Deleting State ignore if no rows found 
	
	select @result as 'Result'
	return @result
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateAllocatedResourcesStateV2]') and type in (N'P', N'PC'))
	drop procedure [UpdateAllocatedResourcesStateV2]
go
create procedure [UpdateAllocatedResourcesStateV2]
	@resourceOwnerType nvarchar(50),
	@iotHubId int,
	@oldState nvarchar(50),
	@newState nvarchar(50),	
	@lastUpdatedTime datetime2 = null,
	@resourceName nvarchar(100) = null,
	@resourceExpirationBufferInSeconds int = 0
as
begin
	declare @result int = 0
	declare @expiryTime datetime

	if @lastUpdatedTime is null set @lastUpdatedTime  = GetUtcDate()
	
	-- Only 2 final transition states are possible currently so expiry times will be set only for these 2 known transitions during update
	-- When the new state is Deleting, the oldState check is removed because all three states Allocated, Committed and Created can move to Deleting
			
	-- Need to mark allocated resources to desired state
	update [ResourceAllocationsTable] 
	set 
		[LastUpdatedTime] = @lastUpdatedTime,				
		[ExpiryTime] = case 							
							-- Do not overwrite the expiry time for a resource that was already in the deleting state or if it is a retry
							when ([ResourceAllocationsTable].[State] = 'Deleting' or @newState = @oldState) 
								then [ExpiryTime] 
							-- On Deleting, compute resources must expire immediately (without any expiration buffer)
							when (@newState = 'Deleting' and [PoolType] = 'ScaleUnit')
								then GetUtcDate()
							-- On Deleting, non-compute resources are marked with an expiration buffer to handle in-flight requests to the resource while waiting for compute to shut down
							when (@newState = 'Deleting' or @newState = 'Restoring')
								then DateAdd(second, @resourceExpirationBufferInSeconds, GetUtcDate())
							-- Only Committed newState is currently possible at this point.  We wipe the ExpiryTime when commiting the resource.
							else null 
						end,
		[State] = @newState
	from
		[ResourceAllocationsTable]
		join [ResourcePoolsTable]
		on  [ResourceAllocationsTable].[ResourcePoolId] = [ResourcePoolsTable].[Id]
	where
		[ResourceOwnerType] = @resourceOwnerType and 
		[IotHubId] = @iotHubId and 
		 -- Following criteria selects three categories of records 
		 -- 1. Select all rows that are already in our newState for idempotency reason. 
		 -- 2. Only if the newState is Deleting, then allow caller to pass null or empty string as oldState as a wild card
		 -- 3. Select all rows that are in oldState to move them to the newState
		(@newState = @oldState or (@newState = 'Deleting' and  @oldState is null or @oldState = '') or [ResourceAllocationsTable].[State] = @oldState) and
		(@resourceName is null or [ResourceName] = @resourceName)

	if (@newState != 'Deleting' and @@rowcount = 0)
		set @result = 12 -- 12: Resource allocation doesn't exist. If we are attempting to move to Deleting State ignore if no rows found 
	
	select @result as 'Result'
	return @result
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetDeletingResourcePoolsV1]') and type in (N'P', N'PC'))
	drop procedure [GetDeletingResourcePoolsV1]
go
create procedure [GetDeletingResourcePoolsV1]
as
begin
	select [ResourcePoolsTable].*, [InternalSubscriptionsTable].[SubscriptionId]
	from [ResourcePoolsTable]
	inner join [InternalSubscriptionsTable]
	on [InternalSubscriptionsTable].[Id] = [ResourcePoolsTable].[InternalSubscriptionsTableId]
    where
            [ResourcePoolsTable].[State] = 'Deleting';
end
go


if exists (select * from sys.objects where object_id = object_id(N'[GetExpiredResourceAllocationsV1]') and type in (N'P', N'PC'))
	drop procedure [GetExpiredResourceAllocationsV1]
go
create procedure [GetExpiredResourceAllocationsV1]
as
begin
	declare @date datetime = GetUtcDate()

	select [ResourceAllocationsTable].*, [ResourcePoolsTable].[Name] as ResourcePoolName, [ResourcePoolsTable].[Region] as Region
	from [ResourceAllocationsTable]
	inner join [ResourcePoolsTable]
	on [ResourcePoolsTable].[Id] = [ResourceAllocationsTable].[ResourcePoolId]
	where
		[ResourceAllocationsTable].[ExpiryTime] IS NOT NULL AND [ResourceAllocationsTable].[ExpiryTime] <= @date 
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetResourceAllocationsV1]') and type in (N'P', N'PC'))
	drop procedure [GetResourceAllocationsV1]
go
create procedure [GetResourceAllocationsV1]
	@name nvarchar(100) = null,
	@iotHubId int = null,
	@state nvarchar(50) = null,
	@poolType nvarchar(50) = null,
	@poolId int = null
as
begin

	declare @cond nvarchar(7) = N' and '
	declare @sql nvarchar(max) = N'select ra.*, rp.[Name] as ResourcePoolName, rp.[Region] as Region
		from [ResourceAllocationsTable] as ra
		inner join [ResourcePoolsTable] as rp
		on rp.[Id] = ra.[ResourcePoolId] 
		where ra.[ResourceOwnerType] = ''IotHub'''

	if @name is not null       select @sql += @cond + N'ra.[ResourceName] = @name '
	if @iotHubId is not null   select @sql += @cond + N'ra.[IotHubId] = @iotHubId '
	if @state is not null      select @sql += @cond + N'ra.[State] = @state '
	if @poolType is not null   select @sql += @cond + N'rp.[PoolType] = @poolType '
	if @poolId is not null     select @sql += @cond + N'rp.[Id] = @poolId '

	execute sp_executesql 
		@sql, 
		N'@name nvarchar(100) = null, @iotHubId int = null, @state nvarchar(50) = null, @poolType nvarchar(50) = null, @poolId int = null', 
		@name, @iotHubId, @state, @poolType, @poolId
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetResourceAllocationsV2]') and type in (N'P', N'PC'))
	drop procedure [GetResourceAllocationsV2]
go
create procedure [GetResourceAllocationsV2]
	@name nvarchar(100) = null,
	@resourceOwnerType nvarchar(50) = null,
	@resourceOwnerId int = null,
	@state nvarchar(50) = null,
	@poolType nvarchar(50) = null,
	@poolId int = null,
	@region nvarchar(50) = null
as
begin

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ra.*, rp.[Name] as ResourcePoolName, rp.[Region] as Region
		from [ResourceAllocationsTable] as ra
		inner join [ResourcePoolsTable] as rp
		on rp.[Id] = ra.[ResourcePoolId]'

	if @name is not null				select @sql += @cond + N'ra.[ResourceName] = @name ', @cond = N' and '
	if @resourceOwnerType is not null   select @sql += @cond + N'ra.[ResourceOwnerType] = @resourceOwnerType ', @cond = N' and '
	if @resourceOwnerId is not null			select @sql += @cond + N'ra.[IotHubId] = @resourceOwnerId ', @cond = N' and '
	if @state is not null				select @sql += @cond + N'ra.[State] = @state ', @cond = N' and '
	if @poolType is not null			select @sql += @cond + N'rp.[PoolType] = @poolType ', @cond = N' and '
	if @poolId is not null				select @sql += @cond + N'rp.[Id] = @poolId ', @cond = N' and '
	if @region is not null				select @sql += @cond + N'rp.[Region] = @region ', @cond = N' and '

	execute sp_executesql 
		@sql, 
		N'@name nvarchar(100) = null, @resourceOwnerType nvarchar(50) = null, @resourceOwnerId int = null, @state nvarchar(50) = null, @poolType nvarchar(50) = null, @poolId int = null, @region nvarchar(50) = null', 
		@name, @resourceOwnerType, @resourceOwnerId, @state, @poolType, @poolId, @region
end
go

---------------------------------
-- ElasticPool CRUD
---------------------------------

if exists (select * from sys.objects where object_id = object_id(N'[CreateElasticPoolV1]') and type in (N'P', N'PC'))
	drop procedure CreateElasticPoolV1
go

create procedure CreateElasticPoolV1
	@elasticPoolName nvarchar(63),	-- Max DNS part length is 63	
	@resourceGroupName nvarchar(128),
	@userSubscriptionId nvarchar(100),
	@state nvarchar(50),
	@resourceDescription nvarchar(max),
	@orchestrationId nvarchar(50) = null,
	@orchestrationLockTime datetime2 = null,
	@orchestrationInput nvarchar(max) = null,
	@createdTime datetime2,
  @region nvarchar(50) = null,
  @skuName nvarchar(20) = null,
  @skuUnits int = 0
as
begin
	declare @result int = 0
	declare @UserSubscriptionsTableId int
	select @UserSubscriptionsTableId = Id from [UserSubscriptionsTable] where [SubscriptionId] = @userSubscriptionId
	if (@UserSubscriptionsTableId is not null)
		begin
			insert into [ElasticPoolsTable] (
				[ElasticPoolName],
				[ResourceGroup],
				[UserSubscriptionsTableId],
				[State],
				[ResourceDescription],
				[CreatedTime],
				[LastUpdatedTime],
				[OrchestrationId],
				[OrchestrationLockTime],
				[OrchestrationExecutionId],
				[OrchestrationInput],
				[Region],
				[SkuName],
				[SkuUnits])
			values (
				@elasticPoolName,
				@resourceGroupName,
				@UserSubscriptionsTableId,
				@state,
				@resourceDescription,
				@createdTime,
				@createdTime,
				@orchestrationId,
				@orchestrationLockTime,
				NULL,
				@orchestrationInput,
				@region,
				@skuName,
				@skuUnits)

			if (@@rowcount = 0)
				set @result = 4 -- Duplicate IotHub name
		end
	else 
		set @result = 3 -- SubscriptionId doesn't exist
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetElasticPoolV1]') and type in (N'P', N'PC'))
	drop procedure [GetElasticPoolV1]
go
create procedure [GetElasticPoolV1]
	@elasticPoolName nvarchar(63) = NULL,
	@orchestrationId nvarchar(50) = NULL,
	@elasticPoolId int = NULL,
	@includeDeletedElasticPoolState bit = 0
as
begin

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ep.*, us.[SubscriptionId]
	from [ElasticPoolsTable] as ep
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ep.[UserSubscriptionsTableId]'

	if @elasticPoolName is not null			select @sql += @cond + N'ep.[ElasticPoolName] = @elasticPoolName ', @cond = N' and '
	if @orchestrationId is not null			select @sql += @cond + N'ep.[OrchestrationId] = @orchestrationId ', @cond = N' and '
	if @elasticPoolId is not null				select @sql += @cond + N'ep.[Id] = @elasticPoolId ', @cond = N' and '
	if @includeDeletedElasticPoolState <> 1	select @sql += @cond + N'ep.[State] != ''Deleted'' ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@elasticPoolName nvarchar(63) = NULL, @orchestrationId nvarchar(50) = NULL, @elasticPoolId int = NULL, @includeDeletedElasticPoolState bit = 0', 
		@elasticPoolName, @orchestrationId, @elasticPoolId, @includeDeletedElasticPoolState
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetElasticPoolsV1]') and type in (N'P', N'PC'))
	drop procedure [GetElasticPoolsV1]
go
create procedure [GetElasticPoolsV1]
	@subscriptionId nvarchar(100) = null,
	@resourceGroup  nvarchar(128) = null,
	@resourcePoolName nvarchar(50) = null
as
begin

	if (@resourcePoolName is not null)
	begin
		CREATE TABLE #Temp
		(
			[ResourcePoolId] int,
			[ResourceName] nvarchar(100),
			[IotHubId] int,
			[State] nvarchar(50),
			[ETag] binary (8),
			[CreatedTime] datetime2(7),
			[LastUpdatedTime] datetime2(7),
			[ExpiryTime] datetime2(7),			
			[Metadata] nvarchar(max),
			[ResourceOwnerType] nvarchar(50),
			[ResourcePoolName] nvarchar(50)
		)

		-- Fetch resource allocations for the resource pool
		declare @poolId int = -1
		select top(1) @poolId = Id from [ResourcePoolsTable] where Name = @resourcePoolName
		INSERT INTO #Temp 
		exec [GetResourceAllocationsV2] null, 'ElasticPool', null, null, null, @poolId
	end

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ep.*, us.[SubscriptionId]
	from [ElasticPoolsTable] as ep
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ep.[UserSubscriptionsTableId]'

	if @subscriptionId is not null      select @sql += @cond + N'us.[SubscriptionId] = @subscriptionId ', @cond = N' and '
	if @resourceGroup is not null       select @sql += @cond + N'ep.[ResourceGroup] = @resourceGroup ', @cond = N' and '
	if @resourcePoolName is not null    select @sql += @cond + N'ep.[Id] in (SELECT IotHubId FROM #Temp) ', @cond = N' and '
	select @sql += @cond + N'ep.[State] != ''Deleted'' ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@subscriptionId nvarchar(100) = null, @resourceGroup  nvarchar(128) = null, @resourcePoolName nvarchar(50) = null', 
		@subscriptionId, @resourceGroup, @resourcePoolName

end
go

if exists (select * from sys.objects where object_id = object_id(N'[DeleteElasticPoolV1]') and type in (N'P', N'PC'))
	drop procedure [DeleteElasticPoolV1]
go
create procedure [DeleteElasticPoolV1]
	@id int,
	@etag rowversion = NULL
as
begin
    declare @result int = 0
	if exists (select [IotHubId] from [ResourceAllocationsTable] where [IotHubId] = @id and [ResourceOwnerType] = 'ElasticPool')
		set @result = 13 -- 13: ElasticPoolsTable has resources allocated in Resource Allocation table
	else
		begin
			begin transaction

				delete [ElasticPoolsTable]
				where [Id] = @id  and
					(@etag is null or [ETag] = @etag)
	
				if (@@rowcount = 0)
					begin
						if not exists (select * from [ElasticPoolsTable] where [Id] = @id)
							set @result = 1 -- IotHub was not found
						else 
							set @result = 2 -- IotHub exists but Etag was invalid
					end
	
			if (@result = 0)
				commit transaction
			else
				rollback transaction
		End
	select @result as 'Result'
end
go


if exists (select * from sys.objects where object_id = object_id(N'[UpdateElasticPoolV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateElasticPoolV1]
go
create procedure [UpdateElasticPoolV1]
	@id int,
	@name nvarchar(63),
	@resourceGroupName nvarchar(128),
	@state nvarchar(50),
	@resourceDescription nvarchar(max),
	@lastUpdatedTime datetime2 = NULL,
	@etag rowversion = NULL,
	@orchestrationId nvarchar(50) = NULL,
	@orchestrationLockTime datetime2(7) = NULL,
	@orchestrationInput nvarchar(max) = NULL,
	@resourceAllocationOperation tinyint = 0,
	@acquireLock bit = 0,	
	@resourceExpirationBufferInSeconds int = 0,
	@updatedUserSubscriptionId nvarchar(max) = NULL,
	@region nvarchar(50) = NULL,
	@skuName nvarchar(20) = NULL,
	@skuUnits int = 0,
	@resourcePoolOwnerType nvarchar(100) = null
as
begin
	declare @result int = 0
	if @lastUpdatedTime is null set @lastUpdatedTime  = GetUtcDate()

	begin transaction
		update [ElasticPoolsTable] 
		set 
			[ResourceGroup] = @resourceGroupName,
			[ElasticPoolName] = @name,
			[State] = @state,
			[ResourceDescription] = @resourceDescription,
			[LastUpdatedTime] = @lastUpdatedTime,
			[OrchestrationId] = @orchestrationId,
			[OrchestrationLockTime] = @orchestrationLockTime,
			[OrchestrationInput] = @orchestrationInput,
			[Region] = @region,
			[SkuName] = @skuName,
			[SkuUnits] = @skuUnits,
			[UserSubscriptionsTableId] = case when @updatedUserSubscriptionId is not null 
				then (select userSubTbl.Id from [UserSubscriptionsTable] as userSubTbl Where userSubTbl.subscriptionId = @updatedUserSubscriptionId) 
				else [UserSubscriptionsTableId]
				end
		where
			[Id] = @id and
			(	
				-- The condition [OrchestrationId] = @orchestrationId  below will be true in 2 cases
				-- Case1 : If an update is happening from within an orchestration 
				-- Case2 : If the activity to take a lock is being attempted again from a parent global orchestration 
				-- The check for acquirelock = 0 is not done here for Case2
				-- Etag check should not be done in this context to ensure idempotency in both case1 and case2.

				[OrchestrationId] = @orchestrationId OR 
				(
					-- If update is being attempted from outside an orchestration, it should only be to acquire a lock and make the state update on the object.
					-- This means that the orchestrationid passed to the stored proc has to be not null and the orchestration id in the DB should be null and the etag should match
					-- Sync updates to the object are disallowed explicitly by disallowing orchestration ID to be passed as null to this stored proc in higher layers
					-- Force cleanup of the orchestration lock will use the UpdateElasticPoolOrchestrationLock stored proc 

					(@etag is null OR [ETag] = @etag) AND [OrchestrationId] is null AND ( @acquireLock = 1 OR @orchestrationId is null)
				)
			)
			and [State] != 'Deleted'

		if (@@rowcount = 0)
		    begin
		        if not exists (select * from [ElasticPoolsTable] where [Id] = @id and [State] != 'Deleted')
				    set @result = 5 -- Elastic Pool does not exist or it is deleted
			    else if @acquireLock = 0 and not exists (select * from [ElasticPoolsTable] where [Id] = @id and [OrchestrationId] = @orchestrationId)
				    set @result = 16 -- Orchestration lock is lost by the current orchestration
			    else if @etag is not null and not exists (select * from [ElasticPoolsTable] where [Id] = @id and [ETag] = @etag)
				    set @result = 1 -- Etag Mismatch
			    else 
				    set @result = 17 -- Object locked by another orchestration
		    end
		else
			begin
					-- Following check is using flags to perform one or more requested operations as part of this transaction
					-- 0: No resource allocation state change
					-- 1: Change resource allocation state to Committed from Created
					-- 2: Change resource allocation state to Deleting from Committed
					-- 4: Change resource allocation state to Deleting from FailingOver
					if ((@resourceAllocationOperation & 1) = 1)
						exec @result = [UpdateAllocatedResourcesStateV2] 'ElasticPool', @id, 'Created', 'Committed', null, null, @resourceExpirationBufferInSeconds
					if ((@resourceAllocationOperation & 2) = 2 and @result = 0)
						exec @result = [UpdateAllocatedResourcesStateV2] 'ElasticPool', @id, '', 'Deleting', null, null, @resourceExpirationBufferInSeconds
					if ((@resourceAllocationOperation & 4) = 4 and @result = 0)
						exec @result = [UpdateAllocatedResourcesStateV2] 'ElasticPool', @id, 'FailingOver', 'Deleting', null, null, @resourceExpirationBufferInSeconds
			end
		begin
			if((@resourceAllocationOperation & 2) = 2 and @result = 0)
				update [ResourcePoolsTable]
				set [State] = 'Deleting'
				where [ResourceOwnerId] = @id and [ResourcePoolOwnerType] = 'ElasticPool'
		end
	if (@result = 0)
		commit transaction
	else
		rollback transaction
	select @result as 'Result'
end
go


if exists (select * from sys.objects where object_id = object_id(N'[CreateElasticPoolIotHubTenantV1]') and type in (N'P', N'PC'))
	drop procedure [CreateElasticPoolIotHubTenantV1]
go
create procedure [CreateElasticPoolIotHubTenantV1]
  @IotHubName nvarchar(63),
  @userSubscriptionId nvarchar(100),
  @resourceGroupName nvarchar(128),
  @state nvarchar(50),
  @resourceDescription nvarchar(max),
  @routingProperties nvarchar(max) = null,
  @orchestrationId nvarchar(50) = null,
  @orchestrationLockTime datetime2 = null,
  @orchestrationInput nvarchar(max) = null,
  @createdTime datetime2,
  @region nvarchar(50) = null,
  @skuName nvarchar(20) = null,
  @skuUnits int = 0,
  @elasticPoolId int = null
as
begin
	declare @result int = 0
	declare @UserSubscriptionsTableId int
	select @UserSubscriptionsTableId = Id from [UserSubscriptionsTable] where [SubscriptionId] = @userSubscriptionId
	if (@UserSubscriptionsTableId is not null)
		begin
			insert into [IotHubsTable] (
				[IotHubName],
				[ResourceGroup],
				[UserSubscriptionsTableId],
				[State],
				[ResourceDescription],
				[RoutingProperties],
				[CreatedTime],
				[LastUpdatedTime],
				[OrchestrationId],
				[OrchestrationLockTime],
				[OrchestrationExecutionId],
				[OrchestrationInput],
				[Region],
				[SkuName],
				[SkuUnits],
				[ElasticPoolId])
			values (
				@IotHubName,
				@resourceGroupName,
				@UserSubscriptionsTableId,
				@state,
				@resourceDescription,
				@routingProperties,
				@createdTime,
				@createdTime,
				@orchestrationId,
				@orchestrationLockTime,
				NULL,
				@orchestrationInput,
				@region,
				@skuName,
				@skuUnits,
				@elasticPoolId)

			if (@@rowcount = 0)
				set @result = 4 -- Duplicate IotHub name
		end
	else 
		set @result = 3 -- SubscriptionId doesn't exist
	select @result as 'Result'
end
go


if exists (select * from sys.objects where object_id = object_id(N'[GetElasticPoolIotHubTenantV1]') and type in (N'P', N'PC'))
	drop procedure [GetElasticPoolIotHubTenantV1]
go
create procedure [GetElasticPoolIotHubTenantV1]
  @iotHubName nvarchar(63) = NULL,
  @orchestrationId nvarchar(50) = NULL,
  @iotHubId int = NULL,
  @elasticPoolName nvarchar(63) = NULL,
  @elasticPoolId int = NULL,
  @includeDeletedIotHubState bit = 0
as
begin

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'
  select ih.*, us.[SubscriptionId], ep.[ElasticPoolName]
	from [IotHubsTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]
  inner join [ElasticPoolsTable] as ep
  on ih.[ElasticPoolId] = ep.[Id]'

	if @iotHubName is not null			select @sql += @cond + N'ih.[IotHubName] = @iotHubName ', @cond = N' and '
	if @orchestrationId is not null		select @sql += @cond + N'ih.[OrchestrationId] = @orchestrationId ', @cond = N' and '
	if @iotHubId is not null			select @sql += @cond + N'ih.[Id] = @iotHubId ', @cond = N' and '
  if @elasticPoolName is not null			select @sql += @cond + N'ep.[ElasticPoolName] = @elasticPoolName ', @cond = N' and '
  if @elasticPoolId is not null			select @sql += @cond + N'ep.[Id] = @elasticPoolId ', @cond = N' and '
	if @includeDeletedIotHubState <> 1	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@iotHubName nvarchar(63) = NULL, @orchestrationId nvarchar(50) = NULL, @iotHubId int = NULL, @elasticPoolName nvarchar(63) = NULL, @elasticPoolId int = NULL, @includeDeletedIotHubState bit = 0', 
		@iotHubName, @orchestrationId, @iotHubId, @elasticPoolName, @elasticPoolId, @includeDeletedIotHubState
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetElasticPoolIotHubTenantsV1]') and type in (N'P', N'PC'))
	drop procedure [GetElasticPoolIotHubTenantsV1]
go
create procedure [GetElasticPoolIotHubTenantsV1]
	@subscriptionId nvarchar(100) = null,
	@resourceGroup  nvarchar(128) = null,
	@resourcePoolName nvarchar(50) = null,
  @elasticPoolName nvarchar(63) = null,
  @elasticPoolId int = null
as
begin

	if (@resourcePoolName is not null)
	begin
		CREATE TABLE #Temp
		(
			[ResourcePoolId] int,
			[ResourceName] nvarchar(100),
			[IotHubId] int,
			[State] nvarchar(50),
			[ETag] binary (8),
			[CreatedTime] datetime2(7),
			[LastUpdatedTime] datetime2(7),
			[ExpiryTime] datetime2(7),			
			[Metadata] nvarchar(max),
			[ResourceOwnerType] nvarchar(50),
			[ResourcePoolName] nvarchar(50)
		)

		-- Fetch resource allocations for the resource pool
		declare @poolId int = -1
		select top(1) @poolId = Id from [ResourcePoolsTable] where Name = @resourcePoolName
		INSERT INTO #Temp 
		exec [GetResourceAllocationsV2] null, 'ElasticPool', null, null, null, @poolId
	end

  declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'
  select ih.*, us.[SubscriptionId], ep.[ElasticPoolName]
	from [IotHubsTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]
  inner join [ElasticPoolsTable] as ep
  on ep.[Id] = ih.[ElasticPoolId]'

	if @subscriptionId is not null      select @sql += @cond + N'us.[SubscriptionId] = @subscriptionId ', @cond = N' and '
	if @resourceGroup is not null       select @sql += @cond + N'ih.[ResourceGroup] = @resourceGroup ', @cond = N' and '
  if @elasticPoolName is not null			select @sql += @cond + N'ep.[ElasticPoolName] = @elasticPoolName ', @cond = N' and '
  if @elasticPoolId is not null			select @sql += @cond + N'ep.[Id] = @elasticPoolId ', @cond = N' and '
  if @resourcePoolName is not null    select @sql += @cond + N'ih.[Id] in (SELECT IotHubId FROM #Temp WHERE ResourceOwnerType = ''IotHub'') ', @cond = N' and '
	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '
		
	execute sp_executesql 
		@sql, 
		N'@subscriptionId nvarchar(100) = null, @resourceGroup  nvarchar(128) = null, @elasticPoolName nvarchar(63) = null, @elasticPoolId int = null, @resourcePoolName nvarchar(50) = null', 
		@subscriptionId, @resourceGroup, @elasticPoolName, @elasticPoolId, @resourcePoolName

end
go


---------------------------------
-- IotHub Events related stored procs
---------------------------------
if exists (select * from sys.objects where object_id = object_id(N'[CreateIotHubEventV1]') and type in (N'P', N'PC'))
	drop procedure [CreateIotHubEventV1]
go
create procedure [CreateIotHubEventV1]
    @events [IotHubEventsTableTypeV1] READONLY
as
begin
    declare @result int = 0

		insert into [IotHubEventsTable] ([IotHubId], [EventEmissionTime], [EventOccurrenceTime], [EventType], [EventDetail1], [EventDetail2])
		select e.[IotHubId], GetUtcDate(), e.[EventOccurrenceTime], e.[EventType], e.[EventDetail1], e.[EventDetail2] from @events e
	
	if (@@rowcount = 0)
		set @result = 19

    select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetIotHubEventsV1]') and type in (N'P', N'PC'))
	drop procedure [GetIotHubEventsV1]
go
create procedure [GetIotHubEventsV1]
	@iotHubId int,
    @fromDate datetime2 = '0001-01-01',
    @tillDate datetime2 = '9999-12-31',
    @eventType int = 32767, -- bitmask of event types (32767 = pow(2, 15) - 1 )
    @occurrenceSortOrder bit = 0, -- asc
    @top int = 2147483647 -- maxint
as
begin
	select top (@top)
        e.[IotHubId], 
	e.[EventEmissionTime], 
        e.[EventOccurrenceTime], 
        e.[EventType], 
        e.[EventDetail1],
        e.[EventDetail2]
    from 
        [IotHubEventsTable] e
	where 
        e.[IotHubId] = @iotHubId and
        e.[EventOccurrenceTime] between @fromDate and @tillDate and
        ( @eventType = 32767 or ( e.[EventType] & @eventType != 0 ) )
    order by 
    case when @occurrenceSortOrder = 0 then
        e.[EventOccurrenceTime]
        end asc,
    case when @occurrenceSortOrder = 1 then
        e.[EventOccurrenceTime]
        end desc
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetUsageRecordPartitionKeysToNotifyV1]') and type in (N'P', N'PC'))
	drop procedure [GetUsageRecordPartitionKeysToNotifyV1]
go
create procedure [GetUsageRecordPartitionKeysToNotifyV1]
as
begin
	select distinct [EventDetail1] as [PartitionKey]
	from [IotHubEventsTable]
	where 
		[EventDetail2] is null and
		[EventDetail1] is not null and
		[EventType] = 4 -- EventType 4 is BillingEventEmitted		
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateBillingEventsNotificationInfoV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateBillingEventsNotificationInfoV1]
go
create procedure [UpdateBillingEventsNotificationInfoV1]
	@partitionKey nvarchar(200),
	@notificationInfo nvarchar(400)
as
begin

    declare @result int = 0

	update [IotHubEventsTable] 
	set 
		[EventDetail2] = @notificationInfo
	where
		[EventDetail1] = @partitionKey and
		[EventType] = 4 -- EventType 4 is BillingEventEmitted

	if (@@rowcount = 0)
		set @result = 20

    select @result as 'Result'
end
go


---------------------------------
-- IotHub CRUD
---------------------------------

if exists (select * from sys.objects where object_id = object_id(N'[CreateIotHubV1]') and type in (N'P', N'PC'))
	drop procedure [CreateIotHubV1]
go
create procedure [CreateIotHubV1]
	@IotHubName nvarchar(63),
	@userSubscriptionId nvarchar(100),
	@resourceGroupName nvarchar(128),
	@state nvarchar(50),
	@resourceDescription nvarchar(max),
	@routingProperties nvarchar(max) = null,
	@orchestrationId nvarchar(50) = null,
	@orchestrationLockTime datetime2 = null,
	@orchestrationInput nvarchar(max) = null,
	@createdTime datetime2,
    @region nvarchar(50) = null,
    @skuName nvarchar(20) = null,
    @skuUnits int = 0,
	@elasticPoolId int = null,
    @replicaInfo nvarchar(max) = null
as
begin
	declare @result int = 0
	declare @UserSubscriptionsTableId int
	select @UserSubscriptionsTableId = Id from [UserSubscriptionsTable] where [SubscriptionId] = @userSubscriptionId
	if (@UserSubscriptionsTableId is not null)
		begin
			insert into [IotHubsTable] (
				[IotHubName],
				[ResourceGroup],
				[UserSubscriptionsTableId],
				[State],
				[ResourceDescription],
				[RoutingProperties],
				[CreatedTime],
				[LastUpdatedTime],
				[OrchestrationId],
				[OrchestrationLockTime],
				[OrchestrationExecutionId],
				[OrchestrationInput],
				[Region],
				[SkuName],
				[SkuUnits],
				[ElasticPoolId],
				[ReplicaInfo])
			values (
				@IotHubName,
				@resourceGroupName,
				@UserSubscriptionsTableId,
				@state,
				@resourceDescription,
				@routingProperties,
				@createdTime,
				@createdTime,
				@orchestrationId,
				@orchestrationLockTime,
				NULL,
				@orchestrationInput,
				@region,
				@skuName,
				@skuUnits,
				@elasticPoolId,
				@replicaInfo)

			if (@@rowcount = 0)
				set @result = 4 -- Duplicate IotHub name
		end
	else 
		set @result = 3 -- SubscriptionId doesn't exist
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateIotHubV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateIotHubV1]
go
create procedure [UpdateIotHubV1]
	@id int,
	@name nvarchar(63),
	@resourceGroupName nvarchar(128),
	@state nvarchar(50),
	@resourceDescription nvarchar(max),
    @routingProperties nvarchar(max) = NULL,
	@lastUpdatedTime datetime2 = NULL,
	@etag rowversion = NULL,
	@orchestrationId nvarchar(50) = NULL,
	@orchestrationLockTime datetime2(7) = NULL,
	@orchestrationInput nvarchar(max) = NULL,
	@resourceAllocationOperation tinyint = 0,
	@acquireLock bit = 0,	
	@events [IotHubEventsTableTypeV1] READONLY,
	@resourceExpirationBufferInSeconds int = 0,
	@updatedUserSubscriptionId nvarchar(max) = NULL,
    @region nvarchar(50) = NULL,
    @skuName nvarchar(20) = NULL,
    @skuUnits int = 0,
	@replicaInfo nvarchar(max) = NULL
as
begin
	declare @result int = 0
	if @lastUpdatedTime is null set @lastUpdatedTime  = GetUtcDate()

	begin transaction
		update [IotHubsTable] 
		set 
			[ResourceGroup] = @resourceGroupName,
			[IotHubName] = @name,
			[State] = @state,
			[ResourceDescription] = @resourceDescription,
			[RoutingProperties] = @routingProperties,
			[LastUpdatedTime] = @lastUpdatedTime,
			[OrchestrationId] = @orchestrationId,
			[OrchestrationLockTime] = @orchestrationLockTime,
			[OrchestrationInput] = @orchestrationInput,
			[Region] = @region,
			[SkuName] = @skuName,
			[SkuUnits] = @skuUnits,
			[ReplicaInfo] = @replicaInfo,
			[UserSubscriptionsTableId] = case when @updatedUserSubscriptionId is not null 
				then (select userSubTbl.Id from [UserSubscriptionsTable] as userSubTbl Where userSubTbl.subscriptionId = @updatedUserSubscriptionId) 
				else [UserSubscriptionsTableId]
				end
		where
			[Id] = @id and
			(	
				-- The condition [OrchestrationId] = @orchestrationId  below will be true in 2 cases
				-- Case1 : If an update is happening from within an orchestration 
				-- Case2 : If the activity to take a lock is being attempted again from a parent global orchestration like import/export iothubs. 
				-- The check for acquirelock = 0 is not done here for Case2
				-- Etag check should not be done in this context to ensure idempotency in both case1 and case2.

				[OrchestrationId] = @orchestrationId OR 
				(
					-- If update is being attempted from outside an orchestration, it should only be to acquire a lock and make the state update on the object.
					-- This means that the orchestrationid passed to the stored proc has to be not null and the orchestration id in the DB should be null and the etag should match
					-- Sync updates to the object are disallowed explicitly by disallowing orchestration ID to be passed as null to this stored proc in higher layers
					-- Force cleanup of the orchestration lock will use the UpdateIotHubOrchestrationLock stored proc 

					(@etag is null OR [ETag] = @etag) AND [OrchestrationId] is null AND ( @acquireLock = 1 OR @orchestrationId is null)
				)
			)
			and [State] != 'Deleted'

		if (@@rowcount = 0)
		begin
		    if not exists (select * from [IotHubsTable] where [Id] = @id and [State] != 'Deleted')
				set @result = 5 -- IotHub does not exist or it is deleted
			else if @acquireLock = 0 and not exists (select * from [IotHubsTable] where [Id] = @id and [OrchestrationId] = @orchestrationId)
				set @result = 16 -- Orchestration lock is lost by the current orchestration
			else if @etag is not null and not exists (select * from [IotHubsTable] where [Id] = @id and [ETag] = @etag)
				set @result = 1 -- Etag Mismatch
			else 
				set @result = 17 -- Object locked by another orchestration
		end
		else
			begin
				
				-- Delete certificates if the hub is deleting
				if (@state = 'Deleting')
					delete from [CertificatesTable] where [IotHubId] = @id 
			    -- Following check is using flags to perform one or more requested operations as part of this transaction
				-- 0: No resource allocation state change
				-- 1: Change resource allocation state to Committed from Created
				-- 2: Change resource allocation state to Deleting from Committed
				-- 4: Change resource allocation state to Deleting from FailingOver
				if ((@resourceAllocationOperation & 1) = 1 )
					exec @result = [UpdateAllocatedResourcesStateV1] @id, 'Created', 'Committed', null, null, @resourceExpirationBufferInSeconds
				if ((@resourceAllocationOperation & 2) = 2 and @result = 0)
					exec @result = [UpdateAllocatedResourcesStateV1] @id, '', 'Deleting', null, null, @resourceExpirationBufferInSeconds
				if ((@resourceAllocationOperation & 4) = 4 and @result = 0)
					exec @result = [UpdateAllocatedResourcesStateV1] @id, 'FailingOver', 'Deleting', null, null, @resourceExpirationBufferInSeconds
				if (@result = 0 and exists (select * from @events))
				begin
					exec @result = [CreateIotHubEventV1] @events 
				end
			end
	if (@result = 0)
		commit transaction
	else
		rollback transaction
			
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateIotHubV2]') and type in (N'P', N'PC'))
	drop procedure [UpdateIotHubV2]
go
create procedure [UpdateIotHubV2]
	@id int,
	@name nvarchar(63),
	@resourceGroupName nvarchar(128),
	@state nvarchar(50),
	@resourceDescription nvarchar(max),
    @routingProperties nvarchar(max) = NULL,
	@lastUpdatedTime datetime2 = NULL,
	@etag rowversion = NULL,
	@orchestrationId nvarchar(50) = NULL,
	@orchestrationLockTime datetime2(7) = NULL,
	@orchestrationInput nvarchar(max) = NULL,
	@resourceAllocationOperation tinyint = 0,
	@acquireLock bit = 0,	
	@events [IotHubEventsTableTypeV1] READONLY,
	@resourceExpirationBufferInSeconds int = 0,
	@updatedUserSubscriptionId nvarchar(max) = NULL,
    @region nvarchar(50) = NULL,
    @skuName nvarchar(20) = NULL,
    @skuUnits int = 0,
    @elasticPoolId int = NULL,
	@replicaInfo nvarchar(max) = NULL
as
begin
	declare @result int = 0
	if @lastUpdatedTime is null set @lastUpdatedTime  = GetUtcDate()

	begin transaction
		update [IotHubsTable] 
		set 
			[ResourceGroup] = @resourceGroupName,
			[IotHubName] = @name,
			[State] = @state,
			[ResourceDescription] = @resourceDescription,
			[RoutingProperties] = @routingProperties,
			[LastUpdatedTime] = @lastUpdatedTime,
			[OrchestrationId] = @orchestrationId,
			[OrchestrationLockTime] = @orchestrationLockTime,
			[OrchestrationInput] = @orchestrationInput,
			[Region] = @region,
			[SkuName] = @skuName,
			[SkuUnits] = @skuUnits,
            [ElasticPoolId] = @elasticPoolId,
			[ReplicaInfo] = @replicaInfo,
			[UserSubscriptionsTableId] = case when @updatedUserSubscriptionId is not null 
				then (select userSubTbl.Id from [UserSubscriptionsTable] as userSubTbl Where userSubTbl.subscriptionId = @updatedUserSubscriptionId) 
				else [UserSubscriptionsTableId]
				end
		where
			[Id] = @id and
			(	
				-- The condition [OrchestrationId] = @orchestrationId  below will be true in 2 cases
				-- Case1 : If an update is happening from within an orchestration 
				-- Case2 : If the activity to take a lock is being attempted again from a parent global orchestration like import/export iothubs. 
				-- The check for acquirelock = 0 is not done here for Case2
				-- Etag check should not be done in this context to ensure idempotency in both case1 and case2.

				[OrchestrationId] = @orchestrationId OR 
				(
					-- If update is being attempted from outside an orchestration, it should only be to acquire a lock and make the state update on the object.
					-- This means that the orchestrationid passed to the stored proc has to be not null and the orchestration id in the DB should be null and the etag should match
					-- Sync updates to the object are disallowed explicitly by disallowing orchestration ID to be passed as null to this stored proc in higher layers
					-- Force cleanup of the orchestration lock will use the UpdateIotHubOrchestrationLock stored proc 

					(@etag is null OR [ETag] = @etag) AND [OrchestrationId] is null AND ( @acquireLock = 1 OR @orchestrationId is null)
				)
			)
			and [State] != 'Deleted'

		if (@@rowcount = 0)
		begin
		    if (@state = 'Deleted' and exists (select * from [IotHubsTable] where [Id] = @id and [IotHubName] like @name + '_[[]%]' and [State] = 'Deleted'))
				set @result = 0
			else if not exists (select * from [IotHubsTable] where [Id] = @id and [State] != 'Deleted')
					set @result = 5 -- IotHub does not exist or it is deleted
			else if @acquireLock = 0 and not exists (select * from [IotHubsTable] where [Id] = @id and [OrchestrationId] = @orchestrationId)
				set @result = 16 -- Orchestration lock is lost by the current orchestration
			else if @etag is not null and not exists (select * from [IotHubsTable] where [Id] = @id and [ETag] = @etag)
				set @result = 1 -- Etag Mismatch
			else 
				set @result = 17 -- Object locked by another orchestration
		end
		else
			begin
				
				-- Delete certificates if the hub is deleting
				if (@state = 'Deleting')
					delete from [CertificatesTable] where [IotHubId] = @id 
				-- Following check is using flags to perform one or more requested operations as part of this transaction
				-- 0: No resource allocation state change
				-- 1: Change resource allocation state to Committed from Created
				-- 2: Change resource allocation state to Deleting from Committed
				-- 4: Change resource allocation state to Deleting from FailingOver
				if ((@resourceAllocationOperation & 1) = 1 )
					exec @result = [UpdateAllocatedResourcesStateV1] @id, 'Created', 'Committed', null, null, @resourceExpirationBufferInSeconds
				if ((@resourceAllocationOperation & 2) = 2 and @result = 0)
					exec @result = [UpdateAllocatedResourcesStateV1] @id, '', 'Deleting', null, null, @resourceExpirationBufferInSeconds
				if ((@resourceAllocationOperation & 4) = 4 and @result = 0)
					exec @result = [UpdateAllocatedResourcesStateV1] @id, 'FailingOver', 'Deleting', null, null, @resourceExpirationBufferInSeconds
				if (@result = 0 and exists (select * from @events))
				begin
					exec @result = [CreateIotHubEventV1] @events 
				end
			end
	if (@result = 0)
		commit transaction
	else
		rollback transaction
			
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateIotHubOrchestrationLockV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateIotHubOrchestrationLockV1]
go
create procedure [UpdateIotHubOrchestrationLockV1]
	@name varchar(63),
	@lockOperation tinyint,
	@orchestrationId nvarchar(50),
	@orchestrationExecutionId nvarchar(50) = NULL,
	@orchestrationInput nvarchar(max) = NULL,
	@etag rowversion = NULL
as
begin
	-- @lockOperation: 
	--		1 - Take LocK (new)
	--		2 - Renew Lock
	--		3 - Clear Lock
	begin transaction
		update [IotHubsTable]
		set 
			[OrchestrationId] = case @lockOperation 
								when 3 then NULL 
								else @orchestrationId end,
			[OrchestrationLockTime] = case @lockOperation 
									  when 3 then NULL 
									  else GetUtcDate() end,
			[OrchestrationExecutionId] = case @lockOperation 
									     when 2 then @orchestrationExecutionId
									     else NULL end,
			[OrchestrationInput] = case @lockOperation 
								   when 3 then NULL 
								   when 2 then [OrchestrationInput]
								   else @orchestrationInput end,
			[LastUpdatedTime] = GetUtcDate()
		where
			[IotHubName] = @name and 
			(
				(@lockOperation = 1 and (([OrchestrationId] is null and [ETag] = @etag) or [OrchestrationId] = @orchestrationId)) -- new lock
				or
				(@lockOperation = 2 and [OrchestrationId] = @orchestrationId and ( [OrchestrationExecutionId] is null or [OrchestrationExecutionId] = @orchestrationExecutionId)) -- renew lock
				or
				(@lockOperation = 3 and ([OrchestrationId] is null or [OrchestrationId] = @orchestrationId)) -- clear lock
			)
		
		if (@@rowcount = 0)
			rollback transaction
		else
			begin
				exec [GetIotHubV1] @name
				commit transaction
			end
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateIotHubOrchestrationLockV2]') and type in (N'P', N'PC'))
	drop procedure [UpdateIotHubOrchestrationLockV2]
go
create procedure [UpdateIotHubOrchestrationLockV2]
	@name varchar(63),
	@lockOperation tinyint,
	@orchestrationId nvarchar(50),
	@orchestrationExecutionId nvarchar(50) = NULL,
	@orchestrationInput nvarchar(max) = NULL,
	@etag rowversion = NULL
as
begin
	-- @lockOperation: 
	--		1 - Take LocK (new)
	--		2 - Renew Lock
	--		3 - Clear Lock
	begin transaction
		update [IotHubsTable]
		set 
			[OrchestrationId] = case @lockOperation 
								when 3 then NULL 
								else @orchestrationId end,
			[OrchestrationLockTime] = case @lockOperation 
									  when 3 then NULL 
									  else GetUtcDate() end,
			[OrchestrationExecutionId] = case @lockOperation 
									     when 2 then @orchestrationExecutionId
									     else NULL end,
			[OrchestrationInput] = case @lockOperation 
								   when 3 then NULL 
								   when 2 then [OrchestrationInput]
								   else @orchestrationInput end,
			[LastUpdatedTime] = GetUtcDate()
		where
			[IotHubName] = @name and 
			(
				(@lockOperation = 1 and (([OrchestrationId] is null and [ETag] = @etag) or [OrchestrationId] = @orchestrationId)) -- new lock
				or
				(@lockOperation = 2 and [OrchestrationId] = @orchestrationId and ( [OrchestrationExecutionId] is null or [OrchestrationExecutionId] = @orchestrationExecutionId)) -- renew lock
				or
				(@lockOperation = 3 and ([OrchestrationId] is null or [OrchestrationId] = @orchestrationId)) -- clear lock
			)
		
		if (@@rowcount = 0)
			rollback transaction
		else
			begin
				exec [GetIotHubV2] @name
				commit transaction
			end
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateElasticPoolOrchestrationLockV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateElasticPoolOrchestrationLockV1]
go
create procedure [UpdateElasticPoolOrchestrationLockV1]
	@name varchar(63),
	@lockOperation tinyint,
	@orchestrationId nvarchar(50),
	@orchestrationExecutionId nvarchar(50) = NULL,
	@orchestrationInput nvarchar(max) = NULL,
	@etag rowversion = NULL
as
begin
	-- @lockOperation: 
	--		1 - Take Lock (new)
	--		2 - Renew Lock
	--		3 - Clear Lock
	begin transaction
		update [ElasticPoolsTable]
		set 
			[OrchestrationId] = case @lockOperation 
								when 3 then NULL 
								else @orchestrationId end,
			[OrchestrationLockTime] = case @lockOperation 
									  when 3 then NULL 
									  else GetUtcDate() end,
			[OrchestrationExecutionId] = case @lockOperation 
									     when 2 then @orchestrationExecutionId
									     else NULL end,
			[OrchestrationInput] = case @lockOperation 
								   when 3 then NULL 
								   when 2 then [OrchestrationInput]
								   else @orchestrationInput end,
			[LastUpdatedTime] = GetUtcDate()
		where
			[ElasticPoolName] = @name and 
			(
				(@lockOperation = 1 and (([OrchestrationId] is null and [ETag] = @etag) or [OrchestrationId] = @orchestrationId)) -- new lock
				or
				(@lockOperation = 2 and [OrchestrationId] = @orchestrationId and ( [OrchestrationExecutionId] is null or [OrchestrationExecutionId] = @orchestrationExecutionId)) -- renew lock
				or
				(@lockOperation = 3 and ([OrchestrationId] is null or [OrchestrationId] = @orchestrationId)) -- clear lock
			)
		
		if (@@rowcount = 0)
			rollback transaction
		else
			begin
				exec [GetElasticPoolV1] @name
				commit transaction
			end
end
go

if exists (select * from sys.objects where object_id = object_id(N'[DeleteIotHubV1]') and type in (N'P', N'PC'))
	drop procedure [DeleteIotHubV1]
go
create procedure [DeleteIotHubV1]
	@id int,
	@etag rowversion = NULL
as
begin
    declare @result int = 0
	if exists (select [IotHubId] from [ResourceAllocationsTable] where [IotHubId] = @id and [ResourceOwnerType] = 'IotHub')
		set @result = 13 -- 13: IotHubTable has resources allocated in Resource Allocation table
	else
		begin
			begin transaction

				delete [IotHubsTable]
				where [Id] = @id  and
					(@etag is null or [ETag] = @etag)
	
				if (@@rowcount = 0)
					begin
						if not exists (select * from [IotHubsTable] where [Id] = @id)
							set @result = 1 -- IotHub was not found
						else 
							set @result = 2 -- IotHub exists but Etag was invalid
					end
				else
					delete from [CertificatesTable] where [IotHubId] = @id

			if (@result = 0)
				commit transaction
			else
				rollback transaction
		End
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetIotHubV1]') and type in (N'P', N'PC'))
	drop procedure [GetIotHubV1]
go
create procedure [GetIotHubV1]
	@IotHubName nvarchar(63) = NULL,
	@orchestrationId nvarchar(50) = NULL,
	@iotHubId int = NULL,
	@includeDeletedIotHubState bit = 0
as
begin

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ih.*, us.[SubscriptionId]
	from [IotHubsTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]'

	if @IotHubName is not null			select @sql += @cond + N'ih.[IotHubName] = @IotHubName ', @cond = N' and '
	if @orchestrationId is not null		select @sql += @cond + N'ih.[OrchestrationId] = @orchestrationId ', @cond = N' and '
	if @iotHubId is not null			select @sql += @cond + N'ih.[Id] = @iotHubId ', @cond = N' and '
	if @includeDeletedIotHubState <> 1	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@IotHubName nvarchar(63) = NULL, @orchestrationId nvarchar(50) = NULL, @iotHubId int = NULL, @includeDeletedIotHubState bit = 0', 
		@IotHubName, @orchestrationId, @iotHubId, @includeDeletedIotHubState
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetIotHubV2]') and type in (N'P', N'PC'))
	drop procedure [GetIotHubV2]
go
create procedure [GetIotHubV2]
	@IotHubName nvarchar(63) = NULL,
	@orchestrationId nvarchar(50) = NULL,
	@iotHubId int = NULL,
	@includeDeletedIotHubState bit = 0
as
begin

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ih.*, us.[SubscriptionId], ep.[ElasticPoolName]
	from [IotHubsTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]
  left join [ElasticPoolsTable] as ep
  on ih.[ElasticPoolId] = ep.[Id]'

	if @IotHubName is not null			select @sql += @cond + N'ih.[IotHubName] = @IotHubName ', @cond = N' and '
	if @orchestrationId is not null		select @sql += @cond + N'ih.[OrchestrationId] = @orchestrationId ', @cond = N' and '
	if @iotHubId is not null			select @sql += @cond + N'ih.[Id] = @iotHubId ', @cond = N' and '
	if @includeDeletedIotHubState <> 1	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@IotHubName nvarchar(63) = NULL, @orchestrationId nvarchar(50) = NULL, @iotHubId int = NULL, @includeDeletedIotHubState bit = 0', 
		@IotHubName, @orchestrationId, @iotHubId, @includeDeletedIotHubState
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetIotHubIncludeDeletedV1]') and type in (N'P', N'PC'))
	drop procedure GetIotHubIncludeDeletedV1
go
create procedure GetIotHubIncludeDeletedV1
	@IotHubName nvarchar(63),
	@orchestrationId nvarchar(50) = NULL,
	@includeDeletedHubs bit = 0
as
begin

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ih.*, us.[SubscriptionId], ep.[ElasticPoolName]
	from [IotHubsTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]
	left join [ElasticPoolsTable] as ep
	on ih.[ElasticPoolId] = ep.[Id]'

	if @IotHubName is not null and 	@includeDeletedHubs = 0	select @sql += @cond + N'ih.[IotHubName] = @IotHubName ', @cond = N' and '
	if @IotHubName is not null and 	@includeDeletedHubs = 1	select @sql += @cond + N'(ih.[IotHubName] = @IotHubName or ih.[IotHubName] like ''' + @IotHubName + '_[[]%]'') ', @cond = N' and '
	if @orchestrationId is not null		select @sql += @cond + N'ih.[OrchestrationId] = @orchestrationId ', @cond = N' and '
	if @includeDeletedHubs = 0	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '

	execute sp_executesql 
		@sql, 
		N'@IotHubName nvarchar(63) = NULL, @orchestrationId nvarchar(50) = NULL, @includeDeletedHubs bit = 0', 
		@IotHubName, @orchestrationId, @includeDeletedHubs
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetIotHubsV1]') and type in (N'P', N'PC'))
	drop procedure [GetIotHubsV1]
go
create procedure [GetIotHubsV1]
	@subscriptionId nvarchar(100) = null,
	@resourceGroup  nvarchar(128) = null,
	@resourcePoolName nvarchar(50) = null
as
begin

	if (@resourcePoolName is not null)
	begin
		CREATE TABLE #Temp
		(
			[ResourcePoolId] int,
			[ResourceName] nvarchar(100),
			[IotHubId] int,
			[State] nvarchar(50),
			[ETag] binary (8),
			[CreatedTime] datetime2(7),
			[LastUpdatedTime] datetime2(7),
			[ExpiryTime] datetime2(7),			
			[Metadata] nvarchar(max),
			[ResourceOwnerType] nvarchar(50),
			[ResourcePoolName] nvarchar(50),
			[Region] nvarchar(50)
		)

		-- Fetch resource allocations for the resource pool
		declare @poolId int = -1
		select top(1) @poolId = Id from [ResourcePoolsTable] where Name = @resourcePoolName
		INSERT INTO #Temp 
		exec [GetResourceAllocationsV1] null, null, null, null, @poolId
	end

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ih.*, us.[SubscriptionId]
	from [IotHubsTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]'

	if @subscriptionId is not null      select @sql += @cond + N'us.[SubscriptionId] = @subscriptionId ', @cond = N' and '
	if @resourceGroup is not null       select @sql += @cond + N'ih.[ResourceGroup] = @resourceGroup ', @cond = N' and '
	if @resourcePoolName is not null    select @sql += @cond + N'ih.[Id] in (SELECT IotHubId FROM #Temp) ', @cond = N' and '
	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@subscriptionId nvarchar(100) = null, @resourceGroup  nvarchar(128) = null, @resourcePoolName nvarchar(50) = null', 
		@subscriptionId, @resourceGroup, @resourcePoolName

end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetIotHubsV2]') and type in (N'P', N'PC'))
	drop procedure [GetIotHubsV2]
go
create procedure [GetIotHubsV2]
	@subscriptionId nvarchar(100) = null,
	@resourceGroup  nvarchar(128) = null,
	@resourcePoolName nvarchar(50) = null
as
begin

	if (@resourcePoolName is not null)
	begin
		CREATE TABLE #Temp
		(
			[ResourcePoolId] int,
			[ResourceName] nvarchar(100),
			[IotHubId] int,
			[State] nvarchar(50),
			[ETag] binary (8),
			[CreatedTime] datetime2(7),
			[LastUpdatedTime] datetime2(7),
			[ExpiryTime] datetime2(7),			
			[Metadata] nvarchar(max),
			[ResourceOwnerType] nvarchar(50),
            [ResourcePoolName] nvarchar(50),
			[Region] nvarchar(50)
		)

		-- Fetch resource allocations for the resource pool
		declare @poolId int = -1
		select top(1) @poolId = Id from [ResourcePoolsTable] where Name = @resourcePoolName
		INSERT INTO #Temp 
		exec [GetResourceAllocationsV1] null, null, null, null, @poolId
	end

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ih.*, us.[SubscriptionId], ep.[ElasticPoolName]
	from [IotHubsTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]
    left join [ElasticPoolsTable] as ep
    on ih.[ElasticPoolId] = ep.[Id]'

	if @subscriptionId is not null      select @sql += @cond + N'us.[SubscriptionId] = @subscriptionId ', @cond = N' and '
	if @resourceGroup is not null       select @sql += @cond + N'ih.[ResourceGroup] = @resourceGroup ', @cond = N' and '
	if @resourcePoolName is not null    select @sql += @cond + N'ih.[Id] in (SELECT IotHubId FROM #Temp WHERE ResourceOwnerType = ''IotHub'') ', @cond = N' and '
	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '
  select @sql += @cond + N'ih.[ElasticPoolId] IS NULL ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@subscriptionId nvarchar(100) = null, @resourceGroup  nvarchar(128) = null, @resourcePoolName nvarchar(50) = null', 
		@subscriptionId, @resourceGroup, @resourcePoolName

end
go

if exists (select * from sys.objects where object_id = object_id(N'[QueryIotHubsV1]') and type in (N'P', N'PC'))
	drop procedure [QueryIotHubsV1]
go
create procedure [QueryIotHubsV1]
	@top int,
	@subscriptionId nvarchar(100) = null,
	@resourceGroup  nvarchar(128) = null,
	@resourceDescriptionMatchString nvarchar(max) = null
as
begin
	select top (@top)
	[IotHubsTable].[IotHubName], [IotHubsTable].[ResourceDescription]
	from [IotHubsTable]
	inner join [UserSubscriptionsTable]
	on [UserSubscriptionsTable].[Id] = [IotHubsTable].[UserSubscriptionsTableId]
	where
		(@subscriptionId is null or [UserSubscriptionsTable].[SubscriptionId] = @subscriptionId) and
		(@resourceGroup is null or [IotHubsTable].[ResourceGroup] = @resourceGroup) and
		(
			([IotHubsTable].[ResourceDescription] like '%' + @resourceDescriptionMatchString + '%') or
			([IotHubsTable].[RoutingProperties] like '%' + @resourceDescriptionMatchString + '%')
		) and
		[IotHubsTable].[State] != 'Deleted'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetDeletedIotHubsV1]') and type in (N'P', N'PC'))
	drop procedure [GetDeletedIotHubsV1]
go
create procedure [GetDeletedIotHubsV1]
	@top int,
	@skip int,
	@lastUpdatedTime datetime2
as
begin
	select [IotHubsTable].*, [UserSubscriptionsTable].[SubscriptionId]
	from [IotHubsTable]
	inner join [UserSubscriptionsTable]
	on [UserSubscriptionsTable].[Id] = [IotHubsTable].[UserSubscriptionsTableId]
	where [LastUpdatedTime] < @lastUpdatedTime and [IotHubsTable].[State] = 'Deleted'
	order by [LastUpdatedTime] asc
  offset @skip rows
	fetch next @top rows only
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetDeletedIotHubsV2]') and type in (N'P', N'PC'))
	drop procedure [GetDeletedIotHubsV2]
go
create procedure [GetDeletedIotHubsV2]
	@top int,
	@skip int,
	@lastUpdatedTime datetime2
as
begin
	select [IotHubsTable].*, [UserSubscriptionsTable].[SubscriptionId], ep.[ElasticPoolName]
	from [IotHubsTable]
	inner join [UserSubscriptionsTable]
	on [UserSubscriptionsTable].[Id] = [IotHubsTable].[UserSubscriptionsTableId]
  left join [ElasticPoolsTable] as ep
  on [IotHubsTable].[ElasticPoolId] = ep.[Id]
	where [IotHubsTable].[LastUpdatedTime] < @lastUpdatedTime and [IotHubsTable].[State] = 'Deleted'
	order by [IotHubsTable].[LastUpdatedTime] asc
	offset @skip rows
	fetch next @top rows only
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetIotHubsUnbilledPeriodInfoV1]') and type in (N'P', N'PC'))
	drop procedure [GetIotHubsUnbilledPeriodInfoV1]
go
create procedure [GetIotHubsUnbilledPeriodInfoV1]
	@prevBillingPeriodEndDateTime datetime2,
	@lastIotHubId int = null,
	@batchSize int = null
as
begin
	SET NOCOUNT ON;
	declare @fetch int;
	declare @skipLastIotHubId int;

	set @skipLastIotHubId = isnull(@lastIotHubId, 0);
	set @fetch = isnull(@batchSize, 2147483647);

	CREATE TABLE #Temp
	(
	  IotHubId int, 
	  DateTimeValue datetime2(7)
	)

	-- Fetch the latest billing event for each iothub
	INSERT INTO #Temp	(IotHubId, DateTimeValue)
	SELECT IotHubId, MAX([EventOccurrenceTime]) from [IotHubEventsTable]
	WHERE [EventType] = 4 -- EventType 4 is BillingEventEmitted
	GROUP BY IotHubId

	-- Fetch the oldest active state changed event for hubs which do not have a billing event
	INSERT INTO #Temp	(IotHubId, DateTimeValue)
	SELECT IotHubId, MIN([EventOccurrenceTime]) from [IotHubEventsTable]
	WHERE [EventType] = 1 -- EventType 1 is StateChangedEvent
	AND [EventDetail1] = 'Active'
	AND [IotHubId] NOT IN (SELECT IotHubId FROM #Temp)
	GROUP BY IotHubId

	-- Get all the Data for the selected Iot Hubs if the occurrence time of the events found above indicate an open billing period
	-- So, if there was a billing event found for a hub, the occurrence time of the max billing event should be less than the previous billing period's enddatetime
	-- Similarly if there was an Active State Change event found for a newly created hub without a corresponding billing event, the occurrence time of the oldest such event 
	-- should be less than the previous billing period's enddatetime
	
    SELECT TOP (@fetch)
	[IotHubsTable].*, evt.[DateTimeValue], [UserSubscriptionsTable].[SubscriptionId]
	from [IotHubsTable]
	   inner join #Temp as evt
	   on evt.IotHubId = [IotHubsTable].Id
	   inner join [UserSubscriptionsTable]
	   on [UserSubscriptionsTable].[Id] = [IotHubsTable].[UserSubscriptionsTableId]
	where [IotHubsTable].[Id] > @skipLastIotHubId	
	and [DateTimeValue] < @prevBillingPeriodEndDateTime
	order by [IotHubsTable].[Id] asc	

end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetIotHubsUnbilledPeriodInfoV2]') and type in (N'P', N'PC'))
	drop procedure [GetIotHubsUnbilledPeriodInfoV2]
go
create procedure [GetIotHubsUnbilledPeriodInfoV2]
	@prevBillingPeriodEndDateTime datetime2,
	@lastIotHubId int = null,
	@batchSize int = null
as
begin
	SET NOCOUNT ON;
	declare @fetch int;
	declare @skipLastIotHubId int;

	set @skipLastIotHubId = isnull(@lastIotHubId, 0);
	set @fetch = isnull(@batchSize, 2147483647);

	CREATE TABLE #Temp
	(
	  IotHubId int, 
	  DateTimeValue datetime2(7)
	)

	-- Fetch the latest billing event for each iothub
	INSERT INTO #Temp	(IotHubId, DateTimeValue)
	SELECT IotHubId, MAX([EventOccurrenceTime]) from [IotHubEventsTable]
	WHERE [EventType] = 4 -- EventType 4 is BillingEventEmitted
	GROUP BY IotHubId

	-- Fetch the oldest active state changed event for hubs which do not have a billing event
	INSERT INTO #Temp	(IotHubId, DateTimeValue)
	SELECT IotHubId, MIN([EventOccurrenceTime]) from [IotHubEventsTable]
	WHERE [EventType] = 1 -- EventType 1 is StateChangedEvent
	AND [EventDetail1] = 'Active'
	AND [IotHubId] NOT IN (SELECT IotHubId FROM #Temp)
	GROUP BY IotHubId

	-- Get all the Data for the selected Iot Hubs if the occurrence time of the events found above indicate an open billing period
	-- So, if there was a billing event found for a hub, the occurrence time of the max billing event should be less than the previous billing period's enddatetime
	-- Similarly if there was an Active State Change event found for a newly created hub without a corresponding billing event, the occurrence time of the oldest such event 
	-- should be less than the previous billing period's enddatetime
	
    SELECT TOP (@fetch)
	[IotHubsTable].*, evt.[DateTimeValue], [UserSubscriptionsTable].[SubscriptionId], ep.[ElasticPoolName]
	from [IotHubsTable]
	   inner join #Temp as evt
	   on evt.IotHubId = [IotHubsTable].Id
	   inner join [UserSubscriptionsTable]
	   on [UserSubscriptionsTable].[Id] = [IotHubsTable].[UserSubscriptionsTableId]
     left join [ElasticPoolsTable] as ep
     on [IotHubsTable].Id = ep.[Id]
	where [IotHubsTable].[Id] > @skipLastIotHubId	and [IotHubsTable].[ElasticPoolId] is NULL
	and [DateTimeValue] < @prevBillingPeriodEndDateTime
	order by [IotHubsTable].[Id] asc	

end
go

---------------------------------
-- Internal Subscription CRUD
---------------------------------

if exists (select * from sys.objects where object_id = object_id(N'[CreateOrUpdateInternalSubscriptionV1]') and type in (N'P', N'PC'))
	drop procedure [CreateOrUpdateInternalSubscriptionV1]
go
create procedure [CreateOrUpdateInternalSubscriptionV1]
    @subscriptionId nvarchar(100),	
    @maxServicebusNamepaces int,
	@maxStorageAccounts int,
	@maxCores int,
	@availableServicebusNamepaces int,
	@availableStorageAccounts int,
	@availableCores int,
	@etag timestamp = null
as
begin
	-- try update first
    update [InternalSubscriptionsTable] 
    set 
        [MaxServicebusNamespaces] = @maxServicebusNamepaces,
        [MaxStorageAccounts] = @maxStorageAccounts,
		[MaxCores] = @maxCores,
        [AvailableServicebusNamespaces] = @availableServicebusNamepaces,
        [AvailableStorageAccounts] = @availableStorageAccounts,
		[AvailableCores] = @availableCores
    where
        [SubscriptionId] = @subscriptionId and
		(@etag is null or [ETag] = @etag)

	-- if not updated, create new entry
	if (@@rowcount = 0)
		insert into [InternalSubscriptionsTable] ([SubscriptionId], [MaxServicebusNamespaces], [MaxStorageAccounts], [MaxCores], [AvailableServicebusNamespaces], [AvailableStorageAccounts], [AvailableCores])
		values(@subscriptionId, @maxServicebusNamepaces, @maxStorageAccounts, @maxCores, @availableServicebusNamepaces, @availableStorageAccounts, @availableCores)

	select 0 as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[DeleteInternalSubscriptionV1]') and type in (N'P', N'PC'))
	drop procedure [DeleteInternalSubscriptionV1]
go
create procedure [DeleteInternalSubscriptionV1]
	@id int,
	@etag timestamp = null
as
begin
    declare @result int = 0
	if exists (select [Id] from [ResourcePoolsTable] where [InternalSubscriptionsTableId] = @id)
		set @result = 6 -- 6 : InternalSubscription has resources allocated in Resource pool
	else
	begin
		begin transaction

		delete [InternalSubscriptionsTable]
		where [Id] = @id and
			  (@etag is null or [ETag] = @etag)
	
		if (@@rowcount = 0)
			set @result = 7 -- 7 : InternalSubscription was not found
		if (@result = 0)
			commit transaction
		else
			rollback transaction
	end

	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetInternalSubscriptionsV1]') and type in (N'P', N'PC'))
	drop procedure [GetInternalSubscriptionsV1]
go
create procedure [GetInternalSubscriptionsV1]
	@subscriptionId nvarchar(100) = null
as
begin
	select *
	from [InternalSubscriptionsTable]
	where
		@subscriptionId is null or [SubscriptionId] = @subscriptionId
end
go

if exists (select * from sys.objects where object_id = object_id(N'[CheckoutInternalSubscriptionV1]') and type in (N'P', N'PC'))
	drop procedure [CheckoutInternalSubscriptionV1]
go
create procedure [CheckoutInternalSubscriptionV1]
	@resourceType nvarchar(50)
as
begin
	begin transaction
		declare @result int = 0
		declare @selectedSubscription int = (Select Top 1 [Id]
			from [InternalSubscriptionsTable]
			where
				0 < case @resourceType
					when 'core' then [AvailableCores]
					when 'namespace' then [AvailableServiceBusNamespaces]
					when 'storage' then [AvailableStorageAccounts]
				end
			order by
				case @resourceType
					when 'core' then [AvailableCores]
					when 'namespace' then [AvailableServiceBusNamespaces]
					when 'storage' then [AvailableStorageAccounts]
				end desc)
		if @selectedSubscription is null
			set @result = 16 -- 16: No available capacity found in Internal subscriptions
		else
			begin
				update [InternalSubscriptionsTable]
				set
					[AvailableCores] = case when 'core' = @resourceType then [AvailableCores] - 1 else [AvailableCores] end,
					[AvailableServiceBusNamespaces] = case when 'namespace' = @resourceType then [AvailableServiceBusNamespaces] - 1 else [AvailableServiceBusNamespaces] end,
					[AvailableStorageAccounts]  = case when 'storage' = @resourceType then [AvailableStorageAccounts] - 1 else [AvailableStorageAccounts] end
				where
					[Id] = @selectedSubscription
				if (@@rowcount = 0)
					set @result = 17 -- 17: Failed to update Internal subscription availability
			end

		if (@result = 0)
			commit transaction
		else
			rollback transaction
	select @selectedSubscription, @result as 'Result'
end
go

---------------------------------
-- Resource Pool CRUD
---------------------------------

if exists (select * from sys.objects where object_id = object_id(N'[CreateResourcePoolV1]') and type in (N'P', N'PC'))
	drop procedure [CreateResourcePoolV1]
go
create procedure [CreateResourcePoolV1]
	@subscriptionId nvarchar(100),
    @name nvarchar(50),
	@region nvarchar(50),
	@poolType nvarchar(50),
	@state nvarchar(50),
	@maxCapacity int,
	@metaData nvarchar(max),
	@capabilities bigint = 0
as
begin
	declare @result int = 0
	declare @internalSubscriptionsTableId int
	select @internalSubscriptionsTableId = Id from [InternalSubscriptionsTable] where [SubscriptionId] = @subscriptionId
	if (@internalSubscriptionsTableId is not null)
		begin
			insert into [ResourcePoolsTable] ([Name], [Region], [PoolType], [State], [MaxCapacity], [AvailableCapacity], [MetaData], [InternalSubscriptionsTableId], [Capabilities])
			values(@name, @region, @poolType, @state, @maxCapacity, @maxCapacity, @metaData, @internalSubscriptionsTableId, @capabilities)
			if (@@rowcount = 0)
				set @result = 8 -- 8 : Duplicate Resource pool name
		end
	else 
		set @result = 7 -- 7 : InternalSubscription was not found
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[CreateResourcePoolV2]') and type in (N'P', N'PC'))
	drop procedure [CreateResourcePoolV2]
go
create procedure [CreateResourcePoolV2]
  @subscriptionId nvarchar(100),
  @name nvarchar(50),
  @region nvarchar(50),
  @poolType nvarchar(50),
  @state nvarchar(50),
  @maxCapacity int,
  @metaData nvarchar(max),
  @capabilities bigint = 0,
  @resourcePoolOwnerType nvarchar(50),
  @resourceOwnerId int = 0
as
begin
	declare @result int = 0
	declare @internalSubscriptionsTableId int
	select @internalSubscriptionsTableId = Id from [InternalSubscriptionsTable] where [SubscriptionId] = @subscriptionId
	if (@internalSubscriptionsTableId is not null)
		begin
			insert into [ResourcePoolsTable] ([Name], [Region], [PoolType], [State], [MaxCapacity], [AvailableCapacity], [MetaData], [InternalSubscriptionsTableId], [Capabilities], [ResourcePoolOwnerType], [ResourceOwnerId])
			values(@name, @region, @poolType, @state, @maxCapacity, @maxCapacity, @metaData, @internalSubscriptionsTableId, @capabilities, @resourcePoolOwnerType, @resourceOwnerId)
			if (@@rowcount = 0)
				set @result = 8 -- 8 : Duplicate Resource pool name
		end
	else 
		set @result = 7 -- 7 : InternalSubscription was not found
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateResourcePoolV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateResourcePoolV1]
go
create procedure [UpdateResourcePoolV1]
	@id int,
	@state nvarchar(50) = null,
	@maxCapacity int = null,
	@metaData nvarchar(max) = null,
	@capabilities bigint = null,
	@resourcePoolOwnerType nvarchar(50) = null
as
begin
	declare @result int = 0

	-- Need to mark allocated resources deleted first
	update [ResourcePoolsTable] 
	set 
		[State] = CASE WHEN @state is null THEN [State] ELSE @state END,
		[MaxCapacity] = CASE WHEN @maxCapacity is null THEN [MaxCapacity] ELSE @maxCapacity END,
		[AvailableCapacity] = [AvailableCapacity] - ([MaxCapacity] - @maxCapacity),
		[MetaData] = CASE WHEN @metaData is null THEN [MetaData] ELSE @metaData END,
		[Capabilities] = CASE WHEN @capabilities is null THEN [Capabilities] ELSE @capabilities END,
		[ResourcePoolOwnerType] = CASE WHEN @resourcePoolOwnerType is null THEN [ResourcePoolOwnerType] ELSE @resourcePoolOwnerType END
	where
		[Id] = @id and
		([AvailableCapacity] - ([MaxCapacity] - @maxCapacity)) >= 0 -- AvailableCapacity must not be negative after update

	if (@@rowcount = 0)
		set @result = 18 -- 18 : Resource pool doesn't exist or invalid MaxCapacity specified

	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[DeleteResourcePoolV1]') and type in (N'P', N'PC'))
	drop procedure [DeleteResourcePoolV1]
go
create procedure [DeleteResourcePoolV1]
	@poolName nvarchar(50)
as
begin
    declare @result int = 0
	if exists (select [ResourcePoolId] from [ResourceAllocationsTable] 
				inner join [ResourcePoolsTable]
				on [ResourcePoolsTable].[Id] = [ResourceAllocationsTable].[ResourcePoolId]
				where [ResourcePoolsTable].[Name] = @poolName)
			set @result = 10 -- 10: ResourcePool has resources allocated in Resource Allocation table
	else
	begin
		begin transaction

		delete [ResourcePoolsTable]
		where [Name] = @poolName
	
		if (@@rowcount = 0)
			set @result = 9 -- 9 : Resource pool doesn't exist
		if (@result = 0)
			commit transaction
		else
			rollback transaction
	end

	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetResourcePoolsV1]') and type in (N'P', N'PC'))
	drop procedure [GetResourcePoolsV1]
go
create procedure [GetResourcePoolsV1]
	@name nvarchar(50) = null,
	@poolType nvarchar(50) = null,
	@subscriptionId nvarchar(100) = null,
	@resourceOwnerId int = null,
	@resourcePoolOwnerType nvarchar(100) = null,
	@region nvarchar(100) = null
as
begin
	select [ResourcePoolsTable].*, [InternalSubscriptionsTable].[SubscriptionId]
	from [ResourcePoolsTable]
	inner join [InternalSubscriptionsTable]
	on [InternalSubscriptionsTable].[Id] = [ResourcePoolsTable].[InternalSubscriptionsTableId]
	where
		(@name is null or [Name] = @name) and
		(@poolType is null or [PoolType] = @poolType) and
		(@subscriptionId is null or [InternalSubscriptionsTable].[SubscriptionId] = @subscriptionId) and
		(@resourceOwnerId is null or [ResourceOwnerId] = @resourceOwnerId) and
		(@resourcePoolOwnerType is null or [ResourcePoolOwnerType] = @resourcePoolOwnerType) and
		(@region is null or [Region] = @region)
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetScaleUnitsFromResourcePoolV1]') and type in (N'P', N'PC'))
	drop procedure [GetScaleUnitsFromResourcePoolV1]
go
create procedure [GetScaleUnitsFromResourcePoolV1]
 
as
begin
       select [ResourcePoolsTable].*
       from [ResourcePoolsTable]
       where
            [ResourcePoolsTable].[PoolType] = 'ScaleUnit';
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetScaleUnitsFromResourcePoolV2]') and type in (N'P', N'PC'))
	drop procedure [GetScaleUnitsFromResourcePoolV2]
go
create procedure [GetScaleUnitsFromResourcePoolV2]
@resourcePoolOwnerType nvarchar(50) = null
as
begin
       select [ResourcePoolsTable].*
       from [ResourcePoolsTable]
       where
            [ResourcePoolsTable].[PoolType] = 'ScaleUnit' and (@resourcePoolOwnerType is null or [ResourcePoolsTable].[ResourcePoolOwnerType] = @resourcePoolOwnerType);
end
go

if exists (select * from sys.objects where object_id = object_id(N'[AllocateResourceV1]') and type in (N'P', N'PC'))
	drop procedure [AllocateResourceV1]
go
create procedure [AllocateResourceV1]
    @resourceName nvarchar(100),
	@iotHubId int,
	@poolType nvarchar(50),
	@region nvarchar(50),
	@expiryTime datetime2 = null,
	@resourcePoolName nvarchar(50) = null,
	@capabilities bigint = 0,
	@metadata nvarchar(max) = null
as
begin
	begin transaction
		declare @result int = 0
		declare @selectedPool int

		update [ResourcePoolsTable]
		set [AvailableCapacity] = [AvailableCapacity] - 1,
		@selectedPool = [Id]
		where [Id] = (Select Top 1 [Id]
			from [ResourcePoolsTable]
			where [PoolType] = @poolType and
				[Region] = @region and
				[AvailableCapacity] > 0 and
				[State] = 'Enabled' and
				(@resourcePoolName is null or [Name] = @resourcePoolName)
			order by [AvailableCapacity] desc)
		if (@@rowcount = 0)
			set @result = 14 -- 14: No available capacity found in Resource Pool
		else
			begin
				declare @date datetime = GetUtcDate()
				if @expiryTime is null 
				begin
					set @expirytime = DATEADD(minute, 60, @date)
				end
				else
				begin
					if @expiryTime < @date
					begin
						set @expirytime = @date
					end
				end

				insert into [ResourceAllocationsTable] ([ResourcePoolId], [ResourceName], [State], [IotHubId], [CreatedTime], [LastUpdatedTime], [ExpiryTime], [Metadata])
				values(@selectedPool, @resourceName, 'Allocated', @iotHubId, @date, @date, @expirytime, @metadata)
				if (@@rowcount = 0)
					set @result = 11 -- 11: Duplicate Resource Allocation name
			end

		if (@result = 0)
			begin
				select @result as 'Result', [ResourceAllocationsTable].*, [ResourcePoolsTable].[Name] as ResourcePoolName, [ResourcePoolsTable].[Region] as Region
				from [ResourceAllocationsTable]
				inner join [ResourcePoolsTable]
				on [ResourcePoolsTable].[Id] = [ResourceAllocationsTable].[ResourcePoolId]
				where [ResourcePoolsTable].[Id] = @selectedPool and [ResourceAllocationsTable].[ResourceName] = @resourceName
				commit transaction
			end
		else
			begin
				rollback transaction
				select @result as 'Result'
			end
end
go

if exists (select * from sys.objects where object_id = object_id(N'[AllocateResourceV2]') and type in (N'P', N'PC'))
	drop procedure [AllocateResourceV2]
go
create procedure [AllocateResourceV2]
    @resourceName nvarchar(100),
	@resourceOwnerType nvarchar(50),
	@iotHubId int,
	@poolType nvarchar(50),
	@region nvarchar(50),
	@expiryTime datetime2 = null,
	@resourcePoolName nvarchar(50) = null,
	@capabilities bigint = 0,
	@metadata nvarchar(max) = null
as
begin
	begin transaction
		declare @result int = 0
		declare @selectedPool int

		update [ResourcePoolsTable]
		set [AvailableCapacity] = [AvailableCapacity] - 1,
		@selectedPool = [Id]
		where [Id] = (Select Top 1 [Id]
			from [ResourcePoolsTable] with (updlock)
				where
				[PoolType] = @poolType and
				[Region] = @region and
				[AvailableCapacity] > 0 and
				[State] = 'Enabled' and
				-- Skip Owner check for System pool. Hack: Also for ElasticPoolTenantEventHubNamespace
				([PoolType] = 'ElasticPoolTenantEventHubNamespace' or [ResourcePoolOwnerType] = 'System' or [ResourcePoolOwnerType] = @resourceOwnerType) and
				(@resourcePoolName is null or [Name] = @resourcePoolName)
			order by [AvailableCapacity] desc)
		if (@@rowcount = 0)
			set @result = 14 -- 14: No available capacity found in Resource Pool
		else
			begin
				declare @date datetime = GetUtcDate()
				if @expiryTime is null 
				begin
					set @expirytime = DATEADD(minute, 60, @date)
				end
				else
				begin
					if @expiryTime < @date
					begin
						set @expirytime = @date
					end
				end

				insert into [ResourceAllocationsTable] ([ResourcePoolId], [ResourceName], [State], [IotHubId], [CreatedTime], [LastUpdatedTime], [ExpiryTime], [Metadata], [ResourceOwnerType])
				values(@selectedPool, @resourceName, 'Allocated', @iotHubId, @date, @date, @expirytime, @metadata, @resourceOwnerType)
				if (@@rowcount = 0)
					set @result = 11 -- 11: Duplicate Resource Allocation name
			end

		if (@result = 0)
			begin
				select @result as 'Result', [ResourceAllocationsTable].*, [ResourcePoolsTable].[Name] as ResourcePoolName, [ResourcePoolsTable].[Region] as Region
				from [ResourceAllocationsTable]
				inner join [ResourcePoolsTable]
				on [ResourcePoolsTable].[Id] = [ResourceAllocationsTable].[ResourcePoolId]
				where [ResourcePoolsTable].[Id] = @selectedPool and [ResourceAllocationsTable].[ResourceName] = @resourceName
				commit transaction
			end
		else
			begin
				rollback transaction
				select @result as 'Result'
			end
end
go

if exists (select * from sys.objects where object_id = object_id(N'[AllocateResourceV3]') and type in (N'P', N'PC'))
	drop procedure [AllocateResourceV3]
go
create procedure [AllocateResourceV3]
    @resourceName nvarchar(100),
	@resourceOwnerType nvarchar(50),
	@iotHubId int,
	@poolType nvarchar(50),
	@region nvarchar(50),
	@expiryTime datetime2 = null,
	@resourcePoolName nvarchar(50) = null,
	@excludeResourcePoolName nvarchar(50) = null,
	@capabilities bigint = 0,
	@metadata nvarchar(max) = null
as
begin
	begin transaction
		declare @result int = 0
		declare @selectedPool int

		update [ResourcePoolsTable]
		set [AvailableCapacity] = [AvailableCapacity] - 1,
		@selectedPool = [Id]
		where [Id] = (Select Top 1 [Id]
			from [ResourcePoolsTable] with (updlock)
				where
				[PoolType] = @poolType and
				[Region] = @region and
				[AvailableCapacity] > 0 and
				[State] = 'Enabled' and
				-- Skip Owner check for System pool. Hack: Also for ElasticPoolTenantEventHubNamespace
				([PoolType] = 'ElasticPoolTenantEventHubNamespace' or [ResourcePoolOwnerType] = 'System' or [ResourcePoolOwnerType] = @resourceOwnerType) and
				(@resourcePoolName is null or [Name] = @resourcePoolName) and
				(@excludeResourcePoolName is null or [Name] != @excludeResourcePoolName)
			order by [AvailableCapacity] desc)
		if (@@rowcount = 0)
			set @result = 14 -- 14: No available capacity found in Resource Pool
		else
			begin
				declare @date datetime = GetUtcDate()
				if @expiryTime is null 
				begin
					set @expirytime = DATEADD(minute, 60, @date)
				end
				else
				begin
					if @expiryTime < @date
					begin
						set @expirytime = @date
					end
				end

				insert into [ResourceAllocationsTable] ([ResourcePoolId], [ResourceName], [State], [IotHubId], [CreatedTime], [LastUpdatedTime], [ExpiryTime], [Metadata], [ResourceOwnerType])
				values(@selectedPool, @resourceName, 'Allocated', @iotHubId, @date, @date, @expirytime, @metadata, @resourceOwnerType)
				if (@@rowcount = 0)
					set @result = 11 -- 11: Duplicate Resource Allocation name
			end

		if (@result = 0)
			begin
				select @result as 'Result', [ResourceAllocationsTable].*, [ResourcePoolsTable].[Name] as ResourcePoolName, [ResourcePoolsTable].[Region] as Region
				from [ResourceAllocationsTable]
				inner join [ResourcePoolsTable]
				on [ResourcePoolsTable].[Id] = [ResourceAllocationsTable].[ResourcePoolId]
				where [ResourcePoolsTable].[Id] = @selectedPool and [ResourceAllocationsTable].[ResourceName] = @resourceName
				commit transaction
			end
		else
			begin
				rollback transaction
				select @result as 'Result'
			end
end
go

if exists (select * from sys.objects where object_id = object_id(N'[DeallocateResourceV1]') and type in (N'P', N'PC'))
	drop procedure [DeallocateResourceV1]
go
create procedure [DeallocateResourceV1]
	@resourceName nvarchar(100)
as
begin
    declare @result int = 0
	begin transaction

	declare @selectedPool int
	select @selectedPool = [ResourcePoolId]
	from [ResourceAllocationsTable]
	where [ResourceName] = @resourceName
	if (@@rowcount = 0)
		set @result = 12 -- 12: Resource allocation doesn't exist
	else
		begin
			delete [ResourceAllocationsTable]
			where [ResourceName] = @resourceName
			update [ResourcePoolsTable]
			set [AvailableCapacity] = [AvailableCapacity] + 1
			where [Id] = @selectedPool
			if (@@rowcount = 0)
				set @result = 15 -- 15: Failed to update Resource Pool availability
		end
	if (@result = 0)
		commit transaction
	else
		rollback transaction

	select @result as 'Result'
end
go

---------------------------------
-- Configuration stored procs
---------------------------------

if exists (select * from sys.objects where object_id = object_id(N'[CreateOrUpdateConfigurationV1]') and type in (N'P', N'PC'))
	drop procedure [CreateOrUpdateConfigurationV1]
go
create procedure [CreateOrUpdateConfigurationV1]
    @scopeKey int,	
    @scopevalue nvarchar(128) = null,
	@configurationSet nvarchar(MAX)
as
begin
	-- try update first
    update [ConfigurationTable] 
    set 
		[Configurations] = @configurationSet
    where
        [ScopeKey] = @scopeKey and
		(@scopevalue is null or [ScopeValue] = @scopevalue)

	-- if not updated, create new entry
	if (@@rowcount = 0)
		insert into [ConfigurationTable] ([ScopeKey], [ScopeValue], [Configurations])
		values(@scopeKey, @scopevalue, @configurationSet)

	select 0 as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetConfigurationV1]') and type in (N'P', N'PC'))
	drop procedure [GetConfigurationV1]
go
create procedure [GetConfigurationV1]
	@scopeKey int,
	@scopeValue nvarchar(128) = null
as
begin
	select [Configurations]
	from [ConfigurationTable] 
	where
		([ScopeKey] = @scopeKey) and
		(@scopeValue is null or [ScopeValue] = @scopeValue) 
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetConfigurationRowV1]') and type in (N'P', N'PC'))
	drop procedure [GetConfigurationRowV1]
go
create procedure [GetConfigurationRowV1]
	@scopeKey int,
	@scopeValue nvarchar(128) = null
as
begin
	select *
	from [ConfigurationTable] 
	where
		([ScopeKey] = @scopeKey) and
		(@scopeValue is null or [ScopeValue] = @scopeValue) 
end
go

if exists (select * from sys.objects where object_id = object_id(N'[DeleteConfigurationV1]') and type in (N'P', N'PC'))
	drop procedure [DeleteConfigurationV1]
go
create procedure [DeleteConfigurationV1]
	@scopeKey int,
	@scopeValue nvarchar(128) = null
as
begin
    declare @result int = 0
	delete [ConfigurationTable] 
		where [ScopeKey] = @scopeKey  and
		(@scopeValue is null or [ScopeValue] = @scopeValue)
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetLockedConfigurationRowsV1]') and type in (N'P', N'PC'))
	drop procedure [GetLockedConfigurationRowsV1]
go
create procedure [GetLockedConfigurationRowsV1]
@count int = 2147483647 -- maxint
as
begin
	select TOP (@count) *
	from [ConfigurationTable] 
	where
		[OrchestrationId] is not null  and
		[OrchestrationLockTime] is not null
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateConfigurationRowLockV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateConfigurationRowLockV1]
go
create procedure [UpdateConfigurationRowLockV1]
	@scopeKey int,
	@scopeValue nvarchar(128),
  @orchestrationLockTime datetime2(7) = NULL,
  @orchestrationId nvarchar(50) = NULL,
  @executionId nvarchar(50) = NULL,
  @etag rowversion = NULL,
  @lockOperation tinyint = 0
as
begin
    -- @lockOperation: 
	  --		1 - Take Lock
	  --		2 - Renew Lock
	  --		3 - Clear Lock  			
    declare @result int = 0
    declare @returnRow bit = 0

    update [ConfigurationTable]
        set [OrchestrationId] = 
                case @lockOperation 
								    when 3 then NULL 
								    else @orchestrationId 
                end,
            [ExecutionId] = 
                case @lockOperation 
								    when 3 then NULL 
								    else @executionId 
                end,
            [OrchestrationLockTime] = 
                case @lockOperation 
								    when 3 then NULL 
                    else @orchestrationLockTime 
                end
        where 
        [ScopeKey] = @scopeKey and 
        [ScopeValue] = @scopeValue and
        (
            (@lockOperation = 1 and ([OrchestrationId] is NULL or [OrchestrationId] = @orchestrationId) and ([ExecutionId] is NULL or [ExecutionId] = @executionId)) or
            (@lockOperation = 2 and [OrchestrationId] = @orchestrationId) or
            (@lockOperation = 3 and (@orchestrationId is NULL or [OrchestrationId] = @orchestrationId) and (@executionId is NULL or [ExecutionId] = @executionId))
        ) and
        (
            (@etag is null) or ([ETag] = @etag)
        )
    
    if (@@rowcount = 0)
		    begin
            if @etag is not null and not exists (select * from [ConfigurationTable] where [ScopeKey] = @scopeKey and [ScopeValue] = @scopeValue and [ETag] = @etag)
				    set @result = 1 -- Etag Mismatch
			      else if @lockOperation != 3
            set @result = 17 -- Object locked by another orchestration
		    end
		else
    set @returnRow = 1
   
    if (@returnRow = 1)
    select @result as 'Result', * from [ConfigurationTable] where ([ScopeKey] = @scopeKey) and (@scopeValue is null or [ScopeValue] = @scopeValue) 
    else
    select @result as 'Result'
    
end
go

if exists (select * from sys.objects where object_id = object_id(N'[CreateOrUpdateConfigurationV2]') and type in (N'P', N'PC'))
	drop procedure [CreateOrUpdateConfigurationV2]
go
create procedure [CreateOrUpdateConfigurationV2]
	@scopeKey int,
	@scopeValue nvarchar(128),
  @configurations nvarchar(MAX) = NULL,
  @orchestrationId nvarchar(50) = NULL,
  @executionId nvarchar(50) = NULL,
  @etag rowversion = NULL
as
begin
    declare @result int = 0
    declare @returnRow bit = 0

    update [ConfigurationTable]
        set
            [Configurations] = case when @configurations is not null then @configurations else [Configurations] end
        where 
        [ScopeKey] = @scopeKey and 
        [ScopeValue] = @scopeValue and
        (
            ([OrchestrationId] is NULL or [OrchestrationId] = @orchestrationId) and 
            ([ExecutionId] is NULL or [ExecutionId] = @executionId)
        ) and
        (
            (@etag is null) or
            ([ETag] = @etag)
        )
    
    if (@@rowcount = 0)
		    begin
            if not exists (select * from [ConfigurationTable] where [ScopeKey] = @scopeKey and [ScopeValue] = @scopeValue)
				      begin
                -- Create row
                insert into [ConfigurationTable] 
                    ([ScopeKey], [ScopeValue], [Configurations])
                values
                    (@scopeKey,
                     @scopeValue,
                     @configurations)
                set @returnRow = 1
              end                
			      else if @etag is not null and not exists (select * from [ConfigurationTable] where [ScopeKey] = @scopeKey and [ScopeValue] = @scopeValue and [ETag] = @etag)
				    set @result = 1 -- Etag Mismatch
			      else
            set @result = 17 -- Object locked by another orchestration
		    end
		else
    set @returnRow = 1
   
    if (@returnRow = 1)
    select @result as 'Result', * from [ConfigurationTable] where ([ScopeKey] = @scopeKey) and (@scopeValue is null or [ScopeValue] = @scopeValue) 
    else
    select @result as 'Result'    
end
go

----------------------------------------
-- Feature filter related stored procs
----------------------------------------

IF TYPE_ID(N'IotHubFeatureFilterTypeV1') IS NULL
BEGIN
CREATE TYPE [IotHubFeatureFilterTypeV1] AS TABLE (
    [FeatureIdentifier] [nvarchar](100) NOT NULL,
    [IotHubFeatureFilter] nvarchar(MAX) NOT NULL)
END
GO

if exists (select * from sys.objects where object_id = object_id(N'[GetFeatureFiltersV1]') and type in (N'P', N'PC'))
	drop procedure [GetFeatureFiltersV1]
go
create procedure [GetFeatureFiltersV1]
as
begin
	select *
	from [FeatureFiltersTable]
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpsertFeatureFiltersV1]') and type in (N'P', N'PC'))
	drop procedure [UpsertFeatureFiltersV1]
go
create procedure [UpsertFeatureFiltersV1]
    @featureFilters [IotHubFeatureFilterTypeV1] READONLY
as
begin
	merge into dbo.[FeatureFiltersTable] as f
        using @featureFilters as i
            on f.[FeatureIdentifier] = i.[FeatureIdentifier]
        when MATCHED then
            UPDATE SET f.[IotHubFeatureFilter] = i.[IotHubFeatureFilter]
        WHEN NOT MATCHED THEN
            INSERT ([FeatureIdentifier], [IotHubFeatureFilter])
            VALUES (i.[FeatureIdentifier], i.[IotHubFeatureFilter]);
end
go

if exists (select * from sys.objects where object_id = object_id(N'[ReplaceFeatureFiltersV1]') and type in (N'P', N'PC'))
	drop procedure [ReplaceFeatureFiltersV1]
go
create procedure [ReplaceFeatureFiltersV1]
    @featureFilters [IotHubFeatureFilterTypeV1] READONLY
as
begin	
	begin transaction		
		-- Wipe the table
		delete [FeatureFiltersTable]

		-- Call the upsert if there is any new data to replace
		if exists(select 1 FROM @featureFilters)
		begin
			exec [UpsertFeatureFiltersV1] @featureFilters
		end
	commit transaction
end
go

if exists (select * from sys.objects where object_id = object_id(N'[DeleteFeatureFilterV1]') and type in (N'P', N'PC'))
	drop procedure [DeleteFeatureFilterV1]
go
create procedure [DeleteFeatureFilterV1]
	@featureIdentifier nvarchar(100)
as
begin
	delete [FeatureFiltersTable]
	where 		
		[FeatureFiltersTable].[FeatureIdentifier] = @featureIdentifier
end
go

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[GetCertificatesV1]') and type in (N'P', N'PC'))
	EXEC('CREATE PROCEDURE [GetCertificatesV1] AS SET NOCOUNT ON;')
GO
ALTER PROCEDURE [GetCertificatesV1]
	@IotHubId INT,
	@Name NVARCHAR(256) = NULL
AS
BEGIN
	SELECT * 
	FROM [CertificatesTable]
	WHERE [IotHubId] = @IotHubId AND (@Name IS NULL OR [Name] = @Name)
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[DeleteCertificateV1]') and type in (N'P', N'PC'))
	EXEC('CREATE PROCEDURE [DeleteCertificateV1] AS SET NOCOUNT ON;')
GO
ALTER PROCEDURE [DeleteCertificateV1]
	@IotHubId BIGINT,
	@Name NVARCHAR(256),
	@ETag ROWVERSION = NULL
AS
BEGIN
	DECLARE @Result INT = 0;

	BEGIN TRAN
		DELETE FROM [CertificatesTable]
		WHERE [IotHubId] = @IotHubId AND [Name] = @Name AND ([ETag] = @ETag OR @ETag IS NULL)

		IF @@ROWCOUNT = 0  
		BEGIN
			BEGIN  
				IF NOT EXISTS (SELECT * FROM [CertificatesTable] WHERE [IotHubId] = @IotHubId AND [Name] = @Name)
					SET @Result = 0 -- Certificate was not found - this is OK
				ELSE 
					SET @Result = 2 -- Certificate exists but ETag does not match
			END; 
		END
	COMMIT TRAN
	
	SELECT @Result as 'Result'

END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[UpsertCertificateV1]') and type in (N'P', N'PC'))
	EXEC('CREATE PROCEDURE [UpsertCertificateV1] AS SET NOCOUNT ON;')
GO
ALTER PROCEDURE [UpsertCertificateV1]
    @IotHubId INT,
	@Name NVARCHAR(256),
	@RawBytes VARBINARY(MAX),
	@IsVerified bit,
	@Purpose INT = NULL,
	@HasPrivateKey bit,
	@Nonce NVARCHAR(100) = NULL,
	@ETag RowVersion = NULL
AS
BEGIN
	DECLARE @Result INT = 0;

	IF (NOT EXISTS(SELECT * FROM [CertificatesTable] WHERE [IotHubId] = @IotHubId AND [Name] = @Name))
	BEGIN
		INSERT INTO [CertificatesTable](
			[IotHubId],
			[Name],
			[RawBytes],
			[IsVerified],
			[Purpose],
			[HasPrivateKey],
			[Nonce],
			[LastUpdated])
		VALUES(
			@IotHubId,
			@Name,
			@RawBytes,
			@IsVerified,
			@Purpose,
			@HasPrivateKey,
			@Nonce,
			GETUTCDATE()
		);
	END
	ELSE
	BEGIN
		BEGIN TRAN
			UPDATE [CertificatesTable]
			SET
				[RawBytes] = @RawBytes,
				[IsVerified] = @IsVerified,
				[Purpose] = @Purpose,
				[HasPrivateKey] = @HasPrivateKey,
				[Nonce] = @Nonce,
				[LastUpdated] = GETUTCDATE()
			WHERE
				[IotHubId] = @IotHubId AND [Name] = @Name AND ([ETag] = @ETag OR @ETag IS NULL);

			IF @@ROWCOUNT = 0  
			BEGIN
				BEGIN  
					IF NOT EXISTS (SELECT * FROM [CertificatesTable] WHERE [IotHubId] = @IotHubId AND [Name] = @Name)
						SET @Result = 1 -- Certificate was not found
					ELSE 
						SET @Result = 2 -- Certificate exists but ETag does not match
				END; 
			END
		COMMIT TRAN
	END	

	IF (@Result = 0)
		SELECT *, @Result as 'Result' FROM [CertificatesTable]
		WHERE [IotHubId] = @IotHubId AND [Name] = @Name;
	ELSE
		SELECT @Result as 'Result'
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[CreateOrUpdateEventGridSubscriptionV1]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [CreateOrUpdateEventGridSubscriptionV1]
GO
CREATE PROCEDURE [CreateOrUpdateEventGridSubscriptionV1]
	@IotHubId INT,
	@EventGridSubscriptionName NVARCHAR(256),
	@EventGridSubscription NVARCHAR(max),
	@ETag RowVersion = NULL
AS
BEGIN
	DECLARE @Result INT = 0
	IF (NOT EXISTS (SELECT * FROM [IotHubsTable] WHERE [Id] = @IotHubId))
		SET @Result = 2 -- 2 : IotHub name doesn't exist
	ELSE
		-- try update first
		-- skipping ETag checks for now. Will be enabled when EG team implements ETag
		UPDATE [EventGridSubscriptionsTable]
		SET
			[EventGridSubscription] = @EventGridSubscription
		WHERE
			[IotHubId] = @IotHubId AND [EventGridSubscriptionName] = @EventGridSubscriptionName -- AND ([ETag] = @ETag OR @ETag IS NULL)

		-- if not updated, create new entry
		IF (@@rowcount = 0)
			INSERT INTO [EventGridSubscriptionsTable] ([IotHubId], [EventGridSubscriptionName], [EventGridSubscription])
			VALUES(@IotHubId, @EventGridSubscriptionName, @EventGridSubscription)

	IF (@Result = 0)
		SELECT *, @Result as 'Result' FROM [EventGridSubscriptionsTable]
		WHERE [IotHubId] = @IotHubId AND [EventGridSubscriptionName] = @EventGridSubscriptionName;
	ELSE
		SELECT @Result as 'Result'
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[GetEventGridSubscriptionV1]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [GetEventGridSubscriptionV1]
GO
CREATE PROCEDURE [GetEventGridSubscriptionV1]
    @IotHubId INT,
	@EventGridSubscriptionName NVARCHAR(256)
AS
BEGIN
	SELECT *
	FROM [EventGridSubscriptionsTable]
	WHERE [IotHubId] = @IotHubId AND [EventGridSubscriptionName] = @EventGridSubscriptionName
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[GetAllEventGridSubscriptionsV1]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [GetAllEventGridSubscriptionsV1]
GO
CREATE PROCEDURE [GetAllEventGridSubscriptionsV1]
    @IotHubId INT
AS
BEGIN
	SELECT *
	FROM [EventGridSubscriptionsTable]
	WHERE [IotHubId] = @IotHubId
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[DeleteEventGridSubscriptionV1]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [DeleteEventGridSubscriptionV1]
GO
CREATE PROCEDURE [DeleteEventGridSubscriptionV1]
    @IotHubId INT,
	@EventGridSubscriptionName NVARCHAR(256)
AS
BEGIN
	DELETE [EventGridSubscriptionsTable]
	WHERE [IotHubId] = @IotHubId AND [EventGridSubscriptionName] = @EventGridSubscriptionName

	SELECT 0 as 'Result'
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[DeleteAllEventGridSubscriptionsV1]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [DeleteAllEventGridSubscriptionsV1]
GO
CREATE PROCEDURE [DeleteAllEventGridSubscriptionsV1]
    @IotHubId INT
AS
BEGIN
	DELETE [EventGridSubscriptionsTable]
	WHERE [IotHubId] = @IotHubId

	SELECT 0 as 'Result'
END
GO