--//----------------------------------------------------------------
--// Copyright (c) Microsoft Corporation.  All rights reserved.
--//----------------------------------------------------------------

set ansi_nulls on
set quoted_identifier on
set nocount on
go

-- TODO: We need think of using SQL exception model instead of these error

-- Return Error Codes
-- 0 : OK
-- 1 : Invalid ETag
-- 2 : Duplicate user subscriptions
-- 3 : User subscription doesn't exist
-- 4 : Duplicate ProvisioningService name
-- 5 : ProvisioningService name doesn't exist
-- 6 : InternalSubscription has resources allocated in Resource pool
-- 7 : InternalSubscription was not found
-- 8 : Duplicate Resource pool name
-- 9 : Resource pool doesn't exist
-- 10: ResourcePool has resources allocated in Resource Allocation table
-- 11: Duplicate Resource Allocation name
-- 12: Resource allocation doesn't exist
-- 13: ProvisioningServiceTable has resources allocated in Resource Allocation table
-- 14: No available capacity found in Resource Pool
-- 15: Failed to update Resource Pool availability
-- 16: Orchestration lock lost
-- 17: Object locked by another Orchestration
-- 18: Resource pool doesn't exist or invalid MaxCapacity specified
-- 19: Error inserting ProvisioningServiceEvents
-- 20: No ProvisioningServiceEvents with the provided partitionkey were found

---------------------------------
-- SubscriptionsTable CRUD
---------------------------------

---------------------------------
-- Resource Allocation CRUD
---------------------------------

-- TODO: These resource allocation methods need DPS variants


---------------------------------
-- ProvisioningService CRUD
---------------------------------

if exists (select * from sys.objects where object_id = object_id(N'[CreateProvisioningServiceV1]') and type in (N'P', N'PC'))
	drop procedure [CreateProvisioningServiceV1]
go
create procedure [CreateProvisioningServiceV1]
	@name nvarchar(63),
	@userSubscriptionId nvarchar(100),
	@resourceGroupName nvarchar(128),
	@state nvarchar(50),
	@resourceDescription nvarchar(max),
	@createdTime datetime2,
	@region nvarchar(50),
    @skuName nvarchar(20),
	@orchestrationId nvarchar(50) = null,
	@orchestrationLockTime datetime2 = null,
	@orchestrationInput nvarchar(max) = null
as
begin
	declare @result int = 0
	declare @UserSubscriptionsTableId int
	select @UserSubscriptionsTableId = Id from [UserSubscriptionsTable] where [SubscriptionId] = @userSubscriptionId
	if (@UserSubscriptionsTableId is not null)
		begin
			insert into [ProvisioningServicesTable] (
				[ProvisioningServiceName],
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
				[SkuName])
			values (
				@name,
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
				@skuName)

			if (@@rowcount = 0)
				set @result = 4 -- Duplicate ProvisioningService name
		end
	else 
		set @result = 3 -- SubscriptionId doesn't exist
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[UpdateProvisioningServiceV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateProvisioningServiceV1]
go
create procedure [UpdateProvisioningServiceV1]
	@id int,
	@name nvarchar(63),
	@resourceGroupName nvarchar(128),
	@state nvarchar(50),
	@resourceDescription nvarchar(max),
	@lastUpdatedTime datetime2,
	@region nvarchar(50),
    @skuName nvarchar(20),
	@etag rowversion = NULL,
	@orchestrationId nvarchar(50) = NULL,
	@orchestrationLockTime datetime2(7) = NULL,
	@orchestrationInput nvarchar(max) = NULL,
	@resourceAllocationOperation tinyint = 0,
	@acquireLock bit = 0,	
	@events [IotHubEventsTableTypeV1] READONLY,
	@resourceExpirationBufferInSeconds int = 0,
	@updatedUserSubscriptionId nvarchar(max) = NULL
as
begin
	declare @result int = 0
	if @lastUpdatedTime is null set @lastUpdatedTime  = GetUtcDate()

	begin transaction
		update [ProvisioningServicesTable] 
		set 
			[ResourceGroup] = @resourceGroupName,
			[ProvisioningServiceName] = @name,
			[State] = @state,
			[ResourceDescription] = @resourceDescription,
			[LastUpdatedTime] = @lastUpdatedTime,
			[OrchestrationId] = @orchestrationId,
			[OrchestrationLockTime] = @orchestrationLockTime,
			[OrchestrationInput] = @orchestrationInput,
			[Region] = @region,
			[SkuName] = @skuName,
			[UserSubscriptionsTableId] = case when @updatedUserSubscriptionId is not null 
				then (select userSubTbl.Id from [UserSubscriptionsTable] as userSubTbl Where userSubTbl.subscriptionId = @updatedUserSubscriptionId) 
				else [UserSubscriptionsTableId]
				end
		where
			[Id] = @id and
			(	
				-- The condition [OrchestrationId] = @orchestrationId  below will be true in 2 cases
				-- Case1 : If an update is happening from within an orchestration 
				-- Case2 : If the activity to take a lock is being attempted again from a parent global orchestration like import/export ProvisioningServices. 
				-- The check for acquirelock = 0 is not done here for Case2
				-- Etag check should not be done in this context to ensure idempotency in both case1 and case2.

				[OrchestrationId] = @orchestrationId OR 
				(
					-- If update is being attempted from outside an orchestration, it should only be to acquire a lock and make the state update on the object.
					-- This means that the orchestrationid passed to the stored proc has to be not null and the orchestration id in the DB should be null and the etag should match
					-- Sync updates to the object are disallowed explicitly by disallowing orchestration ID to be passed as null to this stored proc in higher layers
					-- Force cleanup of the orchestration lock will use the UpdateProvisioningServiceOrchestrationLock stored proc 

					(@etag is null OR [ETag] = @etag) AND [OrchestrationId] is null AND ( @acquireLock = 1 OR @orchestrationId is null)
				)
			)
			and [State] != 'Deleted'

		if (@@rowcount = 0)
		begin
		    if not exists (select * from [ProvisioningServicesTable] where [Id] = @id and [State] != 'Deleted')
				set @result = 5 -- ProvisioningService does not exist or it is deleted
			else if @acquireLock = 0 and not exists (select * from [ProvisioningServicesTable] where [Id] = @id and [OrchestrationId] = @orchestrationId)
				set @result = 16 -- Orchestration lock is lost by the current orchestration
			else if @etag is not null and not exists (select * from [ProvisioningServicesTable] where [Id] = @id and [ETag] = @etag)
				set @result = 1 -- Etag Mismatch
			else 
				set @result = 17 -- Object locked by another orchestration
		end
		else
			begin
				
				-- Delete certificates if the hub is deleting
				if (@state = 'Deleting')
					delete from [ProvisioningServiceCertificatesTable] where [ProvisioningServiceId] = @id 

				-- 0: No resource allocation state change
				-- 1: Change resource allocation state to Committed from Created
				-- 2: Change resource allocation state to Deleting from Committed
				--
				if (@resourceAllocationOperation = 1)
					exec @result = [UpdateAllocatedResourcesStateV2] 'IotDps', @id, 'Created', 'Committed', null, null, @resourceExpirationBufferInSeconds
				else if(@resourceAllocationOperation = 2)
					exec @result = [UpdateAllocatedResourcesStateV2] 'IotDps', @id, '', 'Deleting', null, null, @resourceExpirationBufferInSeconds

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

if exists (select * from sys.objects where object_id = object_id(N'[UpdateProvisioningServiceOrchestrationLockV1]') and type in (N'P', N'PC'))
	drop procedure [UpdateProvisioningServiceOrchestrationLockV1]
go
create procedure [UpdateProvisioningServiceOrchestrationLockV1]
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
		update [ProvisioningServicesTable]
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
			[ProvisioningServiceName] = @name and 
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
				exec [GetProvisioningServiceV1] @name
				commit transaction
			end
end
go

if exists (select * from sys.objects where object_id = object_id(N'[DeleteProvisioningServiceV1]') and type in (N'P', N'PC'))
	drop procedure [DeleteProvisioningServiceV1]
go
create procedure [DeleteProvisioningServiceV1]
	@id int,
	@etag rowversion = NULL
as
begin
    declare @result int = 0
	if exists (select [IotHubId] from [ResourceAllocationsTable] where [IotHubId] = @id and [ResourceOwnerType] = 'ProvisioningService')
		set @result = 13 -- 13: ProvisioningServiceTable has resources allocated in Resource Allocation table
	else
		begin
			begin transaction
				delete [ProvisioningServicesTable]
				where [Id] = @id  and
					(@etag is null or [ETag] = @etag)
	
				if (@@rowcount = 0)
					begin
						if not exists (select * from [ProvisioningServicesTable] where [Id] = @id)
							set @result = 1 -- ProvisioningService was not found
						else 
							set @result = 2 -- ProvisioningService exists but Etag was invalid
					end
				else
					delete from [ProvisioningServiceCertificatesTable] where [ProvisioningServiceId] = @id 

			if (@result = 0)
				commit transaction
			else
				rollback transaction
		End
	select @result as 'Result'
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetProvisioningServiceV1]') and type in (N'P', N'PC'))
	drop procedure [GetProvisioningServiceV1]
go
create procedure [GetProvisioningServiceV1]
	@name nvarchar(63) = NULL,
	@orchestrationId nvarchar(50) = NULL,
	@id int = NULL,
	@includeDeletedProvisioningServiceState bit = 0
as
begin

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ih.*, us.[SubscriptionId]
	from [ProvisioningServicesTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]'

	if @name is not null			select @sql += @cond + N'ih.[ProvisioningServiceName] = @name ', @cond = N' and '
	if @orchestrationId is not null		select @sql += @cond + N'ih.[OrchestrationId] = @orchestrationId ', @cond = N' and '
	if @id is not null			select @sql += @cond + N'ih.[Id] = @id ', @cond = N' and '
	if @includeDeletedProvisioningServiceState <> 1	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@name nvarchar(63) = NULL, @orchestrationId nvarchar(50) = NULL, @id int = NULL, @includeDeletedProvisioningServiceState bit = 0', 
		@name, @orchestrationId, @id, @includeDeletedProvisioningServiceState
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetProvisioningServicesV1]') and type in (N'P', N'PC'))
	drop procedure [GetProvisioningServicesV1]
go
create procedure [GetProvisioningServicesV1]
	@subscriptionId nvarchar(100) = null,
	@resourceGroupName  nvarchar(128) = null,
	@resourcePoolName nvarchar(50) = null
as
begin

	if (@resourcePoolName is not null)
	begin
		CREATE TABLE #Temp
		(
			[ResourcePoolId] int,
			[ResourceName] nvarchar(100),
			[ProvisioningServiceId] int,
			[State] nvarchar(50),
			[ETag] datetime,
			[CreatedTime] datetime2(7),
			[LastUpdatedTime] datetime2(7),
			[ExpiryTime] datetime2(7),
			[ResourcePoolName] nvarchar(50),
			[Metadata] nvarchar(max),
			[ResourceOwnerType] nvarchar(50)
		)

		-- Fetch resource allocations for the resource pool
		declare @poolId int = -1
		select top(1) @poolId = Id from [ResourcePoolsTable] where Name = @resourcePoolName
		INSERT INTO #Temp 
		exec [GetResourceAllocationsV1] null, null, null, null, @poolId
	end

	declare @cond nvarchar(7) = N' where '
	declare @sql nvarchar(max) = N'select ih.*, us.[SubscriptionId]
	from [ProvisioningServicesTable] as ih
	inner join [UserSubscriptionsTable] as us
	on us.[Id] = ih.[UserSubscriptionsTableId]'

	if @subscriptionId is not null      select @sql += @cond + N'us.[SubscriptionId] = @subscriptionId ', @cond = N' and '
	if @resourceGroupName is not null       select @sql += @cond + N'ih.[ResourceGroup] = @resourceGroupName ', @cond = N' and '
	if @resourcePoolName is not null    select @sql += @cond + N'ih.[Id] in (SELECT ProvisioningServiceId FROM #Temp) ', @cond = N' and '
	select @sql += @cond + N'ih.[State] != ''Deleted'' ', @cond = N' and '
	
	execute sp_executesql 
		@sql, 
		N'@subscriptionId nvarchar(100) = null, @resourceGroupName  nvarchar(128) = null, @resourcePoolName nvarchar(50) = null', 
		@subscriptionId, @resourceGroupName, @resourcePoolName

end
go

if exists (select * from sys.objects where object_id = object_id(N'[QueryProvisioningServicesV1]') and type in (N'P', N'PC'))
	drop procedure [QueryProvisioningServicesV1]
go
create procedure [QueryProvisioningServicesV1]
	@top int,
	@skip int,
	@subscriptionId nvarchar(100) = null,
	@resourceGroup  nvarchar(128) = null,
	@resourceDescriptionMatchString nvarchar(max) = null
as
begin
	select 
	[ProvisioningServicesTable].*, [UserSubscriptionsTable].*
	from [ProvisioningServicesTable]
	inner join [UserSubscriptionsTable]
	on [UserSubscriptionsTable].[Id] = [ProvisioningServicesTable].[UserSubscriptionsTableId]
	where
		(@subscriptionId is null or [UserSubscriptionsTable].[SubscriptionId] = @subscriptionId) and
		(@resourceGroup is null or [ProvisioningServicesTable].[ResourceGroup] = @resourceGroup) and
		(
			@resourceDescriptionMatchString is null or
			([ProvisioningServicesTable].[ResourceDescription] like '%' + @resourceDescriptionMatchString + '%')
		) and
		[ProvisioningServicesTable].[State] != 'Deleted'
	order by [ProvisioningServicesTable].[Id] asc
	offset @skip rows
	fetch next @top rows only
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetDeletedProvisioningServicesV1]') and type in (N'P', N'PC'))
	drop procedure [GetDeletedProvisioningServicesV1]
go
create procedure [GetDeletedProvisioningServicesV1]
	@top int,
	@skip int,
	@lastUpdatedTime datetime2
as
begin
	select [ProvisioningServicesTable].*, [UserSubscriptionsTable].[SubscriptionId]
	from [ProvisioningServicesTable]
	inner join [UserSubscriptionsTable]
	on [UserSubscriptionsTable].[Id] = [ProvisioningServicesTable].[UserSubscriptionsTableId]
	where [LastUpdatedTime] < @lastUpdatedTime and [ProvisioningServicesTable].[State] = 'Deleted'
	order by [LastUpdatedTime] asc
	offset @skip rows
	fetch next @top rows only
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetDeletedProvisioningServicesV2]') and type in (N'P', N'PC'))
	drop procedure [GetDeletedProvisioningServicesV2]
go
create procedure [GetDeletedProvisioningServicesV2]
	@top int,
	@skip int,
	@lastUpdatedTime datetime2
as
begin
	select [ProvisioningServicesTable].*, [UserSubscriptionsTable].[SubscriptionId]
	from [ProvisioningServicesTable]
	inner join [UserSubscriptionsTable]
	on [UserSubscriptionsTable].[Id] = [ProvisioningServicesTable].[UserSubscriptionsTableId]
	where [LastUpdatedTime] < @lastUpdatedTime and [ProvisioningServicesTable].[State] = 'Deleted'
	order by [ProvisioningServicesTable].[Id] asc
	offset @skip rows
	fetch next @top rows only
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetDeletedProvisioningServicesV3]') and type in (N'P', N'PC'))
	drop procedure [GetDeletedProvisioningServicesV3]
go
create procedure [GetDeletedProvisioningServicesV3]
	@top int,
	@skip int,
	@lastUpdatedTime datetime2
as
begin
	;with cte AS
	(
		select [ProvisioningServicesTable].*
		from [ProvisioningServicesTable]
		where [LastUpdatedTime] < @lastUpdatedTime and [ProvisioningServicesTable].[State] = 'Deleted'
		order by [ProvisioningServicesTable].[Id] asc
		offset @skip rows
		fetch next @top rows only
	)

	select cte.*, [UserSubscriptionsTable].[SubscriptionId]
	from cte
	inner join [UserSubscriptionsTable]
	on [UserSubscriptionsTable].[Id] = cte.[UserSubscriptionsTableId]
end
go

if exists (select * from sys.objects where object_id = object_id(N'[GetProvisioningServicesUnbilledPeriodInfoV1]') and type in (N'P', N'PC'))
	drop procedure [GetProvisioningServicesUnbilledPeriodInfoV1]
go
create procedure [GetProvisioningServicesUnbilledPeriodInfoV1]
	@prevBillingPeriodEndDateTime datetime2,
	@lastProvisioningServiceId int = null,
	@batchSize int = null
as
begin
	SET NOCOUNT ON;
	declare @fetch int;
	declare @skipLastProvisioningServiceId int;

	set @skipLastProvisioningServiceId = isnull(@lastProvisioningServiceId, 0);
	set @fetch = isnull(@batchSize, 2147483647);

	CREATE TABLE #Temp
	(
	  ProvisioningServiceId int, 
	  DateTimeValue datetime2(7)
	)

	-- Fetch the latest billing event for each ProvisioningService
	INSERT INTO #Temp	(ProvisioningServiceId, DateTimeValue)
	SELECT ProvisioningServiceId, MAX([EventOccurrenceTime]) from [ProvisioningServiceEventsTable]
	WHERE [EventType] = 4 -- EventType 4 is BillingEventEmitted
	GROUP BY ProvisioningServiceId

	-- Fetch the oldest active state changed event for hubs which do not have a billing event
	INSERT INTO #Temp	(ProvisioningServiceId, DateTimeValue)
	SELECT ProvisioningServiceId, MIN([EventOccurrenceTime]) from [ProvisioningServiceEventsTable]
	WHERE [EventType] = 1 -- EventType 1 is StateChangedEvent
	AND [EventDetail1] = 'Active'
	AND [ProvisioningServiceId] NOT IN (SELECT ProvisioningServiceId FROM #Temp)
	GROUP BY ProvisioningServiceId

	-- Get all the Data for the selected Iot Hubs if the occurrence time of the events found above indicate an open billing period
	-- So, if there was a billing event found for a hub, the occurrence time of the max billing event should be less than the previous billing period's enddatetime
	-- Similarly if there was an Active State Change event found for a newly created hub without a corresponding billing event, the occurrence time of the oldest such event 
	-- should be less than the previous billing period's enddatetime
	
    SELECT TOP (@fetch)
	[ProvisioningServicesTable].*, evt.[DateTimeValue], [UserSubscriptionsTable].[SubscriptionId]
	from [ProvisioningServicesTable]
	   inner join #Temp as evt
	   on evt.ProvisioningServiceId = [ProvisioningServicesTable].Id
	   inner join [UserSubscriptionsTable]
	   on [UserSubscriptionsTable].[Id] = [ProvisioningServicesTable].[UserSubscriptionsTableId]
	where [ProvisioningServicesTable].[Id] > @skipLastProvisioningServiceId	
	and [DateTimeValue] < @prevBillingPeriodEndDateTime
	order by [ProvisioningServicesTable].[Id] asc	

end
go

---------------------------------
-- ProvisioningService Certificates related stored procs
---------------------------------

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[GetProvisioningServiceCertificatesV1]') and type in (N'P', N'PC'))
	EXEC('CREATE PROCEDURE [GetProvisioningServiceCertificatesV1] AS SET NOCOUNT ON;')
GO
ALTER PROCEDURE [GetProvisioningServiceCertificatesV1]
	@provisioningServiceId INT,
	@name NVARCHAR(256) = NULL
AS
BEGIN
	SELECT * 
	FROM [ProvisioningServiceCertificatesTable]
	WHERE [ProvisioningServiceId] = @provisioningServiceId AND (@name IS NULL OR [Name] = @name)
END
GO

IF TYPE_ID(N'[StringListTableType]') IS NULL
BEGIN
CREATE TYPE [StringListTableType] AS TABLE (
    [Item] [NVARCHAR](MAX) NULL
    )
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[GetProvisioningServicesByIdV1]') and type in (N'P', N'PC'))
	EXEC('CREATE PROCEDURE [GetProvisioningServicesByIdV1] AS SET NOCOUNT ON;')
GO
ALTER PROCEDURE [GetProvisioningServicesByIdV1]
	@dpsIdList StringListTableType READONLY
as
begin
	select 	* from [ProvisioningServicesTable]	
	where
		[ProvisioningServicesTable].[Id] in (select Item from @dpsIdList)
end
go


IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[DeleteProvisioningServiceCertificateV1]') and type in (N'P', N'PC'))
	EXEC('CREATE PROCEDURE [DeleteProvisioningServiceCertificateV1] AS SET NOCOUNT ON;')
GO
ALTER PROCEDURE [DeleteProvisioningServiceCertificateV1]
	@provisioningServiceId BIGINT,
	@name NVARCHAR(256),
	@etag ROWVERSION = NULL
AS
BEGIN
	DECLARE @Result INT = 0;

	BEGIN TRAN
		DELETE FROM [ProvisioningServiceCertificatesTable]
		WHERE [ProvisioningServiceId] = @provisioningServiceId AND [Name] = @name AND ([ETag] = @ETag OR @etag IS NULL)

		IF @@ROWCOUNT = 0  
		BEGIN
			BEGIN  
				IF NOT EXISTS (SELECT * FROM [ProvisioningServiceCertificatesTable] WHERE [ProvisioningServiceId] = @provisioningServiceId AND [Name] = @name)
					SET @Result = 0 -- Certificate was not found - this is OK
				ELSE 
					SET @Result = 2 -- Certificate exists but ETag does not match
			END; 
		END
	COMMIT TRAN
	
	SELECT @Result as 'Result'

END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[UpsertProvisioningServiceCertificateV1]') and type in (N'P', N'PC'))
	EXEC('CREATE PROCEDURE [UpsertProvisioningServiceCertificateV1] AS SET NOCOUNT ON;')
GO
ALTER PROCEDURE [UpsertProvisioningServiceCertificateV1]
    @provisioningServiceId INT,
	@name NVARCHAR(256),
	@rawBytes VARBINARY(MAX),
	@isVerified bit,
	@purpose INT = NULL,
	@hasPrivateKey bit,
	@nonce NVARCHAR(100) = NULL,
	@etag RowVersion = NULL
AS
BEGIN
	DECLARE @Result INT = 0;

	IF (NOT EXISTS(SELECT * FROM [ProvisioningServiceCertificatesTable] WHERE [ProvisioningServiceId] = @provisioningServiceId AND [Name] = @name))
	BEGIN
		INSERT INTO [ProvisioningServiceCertificatesTable](
			[ProvisioningServiceId],
			[Name],
			[RawBytes],
			[IsVerified],
			[Purpose],
			[HasPrivateKey],
			[Nonce],
			[LastUpdated])
		VALUES(
			@provisioningServiceId,
			@name,
			@rawBytes,
			@isVerified,
			@purpose,
			@hasPrivateKey,
			@nonce,
			GETUTCDATE()
		);
	END
	ELSE
	BEGIN
		BEGIN TRAN
			UPDATE [ProvisioningServiceCertificatesTable]
			SET
				[RawBytes] = @RawBytes,
				[IsVerified] = @IsVerified,
				[Purpose] = @Purpose,
				[HasPrivateKey] = @HasPrivateKey,
				[Nonce] = @Nonce,
				[LastUpdated] = GETUTCDATE()
			WHERE
				[ProvisioningServiceId] = @provisioningServiceId AND [Name] = @name AND ([etag] = @ETag OR @etag IS NULL);

			IF @@ROWCOUNT = 0  
			BEGIN
				BEGIN  
					IF NOT EXISTS (SELECT * FROM [ProvisioningServiceCertificatesTable] WHERE [ProvisioningServiceId] = @provisioningServiceId AND [Name] = @name)
						SET @Result = 1 -- Certificate was not found
					ELSE 
						SET @Result = 2 -- Certificate exists but ETag does not match
				END; 
			END
		COMMIT TRAN
	END	

	IF (@Result = 0)
		SELECT *, @Result as 'Result' FROM [ProvisioningServiceCertificatesTable]
		WHERE [ProvisioningServiceId] = @provisioningServiceId AND [Name] = @name;
	ELSE
		SELECT @Result as 'Result'
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'[GetProvisioningServicesByNameV1]') and type in (N'P', N'PC'))
	EXEC('CREATE PROCEDURE [GetProvisioningServicesByNameV1] AS SET NOCOUNT ON;')
GO
ALTER PROCEDURE [GetProvisioningServicesByNameV1]
	@dpsNamesList StringListTableType READONLY
as
begin
	select 	* from [ProvisioningServicesTable]	
	where
		[ProvisioningServicesTable].[ProvisioningServiceName] in (select Item from @dpsNamesList)
end
go