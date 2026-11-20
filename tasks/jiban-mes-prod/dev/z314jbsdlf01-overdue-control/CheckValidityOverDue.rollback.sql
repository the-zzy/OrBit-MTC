-- =============================================
-- Author:1003439
-- Create date:2026.11.19
-- Description:2026-11-19 撤销 Z314JBSDLF01 料号超周期管控
-- =============================================
ALTER PROCEDURE [dbo].[CheckValidityOverDue]
    @I_Sender NVARCHAR(200) = '' ,		--客户端按钮名称
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,			--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,			--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKid CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
	@LotSN NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;

	--SET DATEFIRST 7;  -- 确保 1=周日, 2=周一, ..., 7=周六

	---- =============================================
	---- 特殊时间段校验：工作日 20:30-7:30 或 周六20:30-周日7:30
	---- 特殊时间段内不执行存储过程，直接返回
	---- =============================================
	--DECLARE @CurrentTime DATETIME = GETDATE();
	--DECLARE @Hour INT = DATEPART(HOUR, @CurrentTime);
	--DECLARE @Minute INT = DATEPART(MINUTE, @CurrentTime);
	--DECLARE @WeekDay INT = DATEPART(WEEKDAY, @CurrentTime); -- 1=周日, 2=周一, ..., 7=周六
	--DECLARE @IsSpecialTime BIT = 0;

	---- 工作日 20:30 - 次日 7:30
	--IF (@WeekDay BETWEEN 2 AND 6) AND ((@Hour > 20) OR (@Hour = 20 AND @Minute >= 02) OR (@Hour < 7) OR (@Hour = 7 AND @Minute < 30))
	--BEGIN
	--	SET @IsSpecialTime = 1;
	--END
	---- 周六 20:30 - 周日 7:30
	--ELSE IF @WeekDay = 7 AND ((@Hour > 20) OR (@Hour = 20 AND @Minute >= 30))
	--BEGIN
	--	SET @IsSpecialTime = 1;
	--END
	--ELSE IF @WeekDay = 1 AND (@Hour < 7 OR (@Hour = 7 AND @Minute < 30))
	--BEGIN
	--	SET @IsSpecialTime = 1;
	--END

	---- 特殊时间段直接返回，不执行任何后续逻辑
	--IF @IsSpecialTime = 1
	--BEGIN
	--	RETURN;
	--END


	SET DATEFIRST 7;  -- 1=周日, 2=周一, ..., 7=周六

	DECLARE @CurrentTime DATETIME = GETDATE();  -- 周六 20:30 -> 拦截 ⭐
	DECLARE @WeekDay INT = DATEPART(WEEKDAY, @CurrentTime);
	DECLARE @MinutesToday INT = DATEDIFF(MINUTE, CAST(@CurrentTime AS DATE), @CurrentTime);
	DECLARE @IsSpecialTime BIT = 0;

	-- 工作日（周一～周五）20:30 - 次日 07:30
	IF @WeekDay BETWEEN 2 AND 6
	   AND (@MinutesToday >= 1230 OR @MinutesToday < 450)
	BEGIN
		SET @IsSpecialTime = 1;
	END

	-- 周末：周六 20:30 ~ 周一 07:30
	IF (@WeekDay = 7 AND @MinutesToday >= 1230)   -- 周六 20:30~23:59
	   OR @WeekDay = 1                             -- 周日 全天
	BEGIN
		SET @IsSpecialTime = 1;
	END


-- 临时表：接收仓库库存查询结果
	IF OBJECT_ID('tempdb..#WarehouseStorageResult') IS NOT NULL
	    DROP TABLE #WarehouseStorageResult;

	CREATE TABLE #WarehouseStorageResult (
	    WarehouseName NVARCHAR(50) NULL,
	    WHPerson NVARCHAR(50) NULL,
	    CellName NVARCHAR(50) NULL,
	    ProductName NVARCHAR(50) NULL,               -- 料号
	    ProductDescription NVARCHAR(200) NULL,       -- 物料信息
	    LotSN NVARCHAR(50) NULL,
	    BoxSN NVARCHAR(50) NULL,
	    ProductionDateCode NVARCHAR(50) NULL,        -- 周期
	    ProductionLotNO NVARCHAR(50) NULL,
	    VendorName NVARCHAR(50) NULL,                -- 供应商编码
	    VendorDescription NVARCHAR(200) NULL,         -- 供应商
	    LotStatus NVARCHAR(10) NULL,
	    LotQty FLOAT NULL,
	    OriginalQty FLOAT NULL,
	    OriginalLotSN NVARCHAR(50) NULL,
	    IsSplit BIT NULL,
	    IsStorage BIT NULL,
	    IsCheck BIT NULL,
	    IsLock BIT NULL,
	    StorageDate DATETIME NULL,
	    BillsType NVARCHAR(50) NULL,
	    BillsNumber NVARCHAR(50) NULL,
		znum NVARCHAR(50) NULL,
		createdate DATETIME
	);

	DECLARE @LotOrBoxSN NVARCHAR(50) = @LotSN; -- 主批号
	DECLARE @ProductDescription NVARCHAR(50) = '';
	DECLARE @ProductName NVARCHAR(100);
    DECLARE @VendorName CHAR(12) = '';
    DECLARE @VendorDescription NVARCHAR(100) = '';
    DECLARE @ProductionDateCode NVARCHAR(50) = '';
	DECLARE @Message NVARCHAR(50) = '';

	-- 企业微信推送参数 
	DECLARE @WXKey VARCHAR(100) = 'fbb6ba44-4547-4add-b762-e0228817b606';
	DECLARE @WXMsg NVARCHAR(MAX) = '';  -- 消息内容
	DECLARE @WXWorkcode VARCHAR(200) = '';  -- 工号
	DECLARE @WXType VARCHAR(10) = 'markdown';  -- 消息类型
	DECLARE @WXReturnMessage NVARCHAR(100) = '';  -- 返回消息（OUTPUT参数）

	DECLARE @UserId NVARCHAR(20) = '';
	set @UserId = N'SUR1000007XD';

		--EXEC WarehouseStorageQueryDoMethod @I_Sender = 'StorageQuery',@I_OrBitUserId = @UserId,@LotOrBoxSN = @LotOrBoxSN, @IsInventory = 1;


	-- 根据条码(主批号)查询成功后，将结果插入临时表, 查询已入库的记录 @IsInventory = 1
	INSERT INTO #WarehouseStorageResult
	(
	    WarehouseName,
	    WHPerson,
	    CellName,
	    ProductName,
	    ProductDescription,
	    LotSN,
	    BoxSN,
	    ProductionDateCode,
	   -- ProductionLotNO,
	    VendorName,
	    VendorDescription,
	    LotStatus,
	    LotQty,
	    OriginalQty,
	    OriginalLotSN,
	    IsSplit,
	    IsStorage,
	    IsCheck,
	    IsLock,
	    StorageDate,
	    BillsType,
	    BillsNumber --,znum,createdate
	)
	EXEC [WarehouseStorageQueryForPDA_DoMethod] @I_Sender = 'StorageQuery',@I_OrBitUserId = @UserId,@LotOrBoxSN = @LotOrBoxSN, @IsInventory = 1;

	PRINT '666'

	-- 从临时表查询数据
	SELECT @ProductName = ProductName, -- 料号
	       @VendorName = VendorName, -- 供应商编码,
           @VendorDescription = VendorDescription, -- 供应商,
			@ProductionDateCode = ProductionDateCode,  -- 周期
			@ProductDescription = ProductDescription -- 物料信息
	FROM #WarehouseStorageResult; 


	DECLARE @RemainingWeeks INT;
	DECLARE @ReturnMessage NVARCHAR(500);
	DECLARE @ReturnValue INT;

	EXEC @ReturnValue = dbo.CheckMaterialStorageThreeValidity 
		@ProductName = @ProductName,   -- 从数据库获取的实际过期料号 
		@DataCode = @ProductionDateCode,       -- 2515 2025年第40周（20250927 转换为周格式） 
		@RemainingWeeks = @RemainingWeeks OUTPUT,
		@I_ReturnMessage = @ReturnMessage OUTPUT;

		--SELECT '777'

	-- 检查 ReturnValue 是否为 -1
	IF @ReturnValue = -1
	BEGIN
	      -- 记录日志：已进入
	      EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '已进入ReturnValue=-1分支';

		-- 检查是否在24小时允发名单中, 不存在时才执行 
		-- 按料号+供应商号+D/C周期进行管控
		IF NOT EXISTS (SELECT 1 FROM MaterialOverdueAllowList WITH (NOLOCK) 
			WHERE ProductName = @ProductName AND VendorName = @VendorName AND ProductionDateCode = @ProductionDateCode ) --不在名单时，则校验
		BEGIN	
		    -- 记录日志：已进入2
		    EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '不在24小时允发名单中，开始校验';
			
			-- 判断料号是否为特殊料号（303/203开头）
			DECLARE @IsSpecialMaterial BIT = 0;

			DECLARE @ProductCode NVARCHAR(12) = @ProductName; -- 变量,后续改成 @ProductName 
     
			-- 检查料号开头: K303/S303/Z303/N303/SN303/K203/S203/Z203/N203/SN203 
			DECLARE @SpecialPrefixes TABLE (Prefix NVARCHAR(10));
			INSERT INTO @SpecialPrefixes (Prefix) VALUES 
				('K303'), ('S303'), ('Z303'), ('N303'), ('SN303'),
				('K203'), ('S203'), ('Z203'), ('N203'), ('SN203');

			IF EXISTS (SELECT 1 FROM @SpecialPrefixes 
				   WHERE @ProductCode LIKE Prefix + '%')
			BEGIN
				SET @IsSpecialMaterial = 1;
			END
			ELSE
			BEGIN
				-- 检查前三位数字是否为303或203
				DECLARE @FirstThreeDigits NVARCHAR(3);
				SET @FirstThreeDigits = LEFT(@ProductCode, 3);
				IF ISNUMERIC(@FirstThreeDigits) = 1
				BEGIN
					IF @FirstThreeDigits IN ('303', '203')
					SET @IsSpecialMaterial = 1;
				END
			END

			SELECT @IsSpecialMaterial AS IsSpecialMaterial -- 是否是特殊料号

			-- 记录日志：已进入3
			EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '开始判断是否在监控台账中';

			-- 判断是否在监控台账中（按料号+供应商号+D/C周期）
			DECLARE @IsInMonitor BIT = 0;
			DECLARE @MonitorControlStatus NVARCHAR(20) = '';
    
			IF EXISTS (SELECT 1 FROM dbo.MaterialOverdueMonitor WITH (NOLOCK)
				   WHERE ProductName = @ProductName AND VendorName = @VendorName AND ProductionDateCode = @ProductionDateCode)
			BEGIN
				SET @IsInMonitor = 1; -- 在监控台账中
				SELECT @MonitorControlStatus = ControlStatus  -- 状态，已确认，未处理
				FROM dbo.MaterialOverdueMonitor WITH (NOLOCK)
				WHERE ProductName = @ProductName AND VendorName = @VendorName AND ProductionDateCode = @ProductionDateCode;
			END

			SELECT @IsInMonitor AS IsInMonitor


			-- 校验303/203逻辑 在监控台账的情况
			IF @IsSpecialMaterial = 1
			BEGIN
				IF @IsInMonitor = 1 -- 在台账中  
				BEGIN
					-- 记录日志：已进入4
					EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '特殊料号在监控台账中';
					
					IF @MonitorControlStatus = '未处理'
					BEGIN
						SET @I_ReturnMessage = '物料超期已被锁定，禁止发料，已通知IQC前往确认1';
						
						-- 记录日志：物料被锁定1
						EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '物料超期已被锁定，禁止发料，已通知IQC前往确认1';
						
						RETURN;
					END

					IF @MonitorControlStatus = '已确认'
					BEGIN
						-- 记录日志：正常发料1
						EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '正常发料1';
					END
				END
			END

			-- 判断是否已被锁定（按料号+供应商号+D/C周期）
			IF EXISTS (SELECT 1 FROM dbo.MaterialOverdueLock WITH (NOLOCK)
				   WHERE ProductName = @ProductName AND VendorName = @VendorName AND ProductionDateCode = @ProductionDateCode
				 	 AND IsActive = 1)
			BEGIN
				SET @I_ReturnMessage = '物料已被锁定，禁止发料，请联系IQC现场确认2';
				
				-- 记录日志：物料被锁定2
				EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '物料已被锁定，禁止发料，请联系IQC现场确认2';
				
				RETURN;
			END


			-- 校验303/203逻辑 不在监控台账的情况
			IF @IsSpecialMaterial = 1
			BEGIN
				 -- 不在监控台账，插入监控记录
				IF @IsInMonitor = 0
				BEGIN
					-- 记录日志：已进入5
					EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '特殊料号不在监控台账，准备插入监控记录';
					
					 -- 特殊料号：锁住该料号+供应商+周期
					DECLARE @LockId CHAR(12);
					EXEC dbo.SysGetObjectPKId '', 'MaterialOverdueLock', @LockId OUTPUT;
       
					INSERT INTO dbo.MaterialOverdueLock
						(LockId, ProductName, VendorName, ProductionDateCode, LotSN, LockReason, CreateDate, IsActive)
					VALUES
						(@LockId, @ProductName, @VendorName, @ProductionDateCode, @LotOrBoxSN, '超周期特殊料号303/203锁定', GETDATE(), 1);

					-- 记录日志：锁住料号成功
					EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '锁住料号成功';

					-- 插入监控记录
					DECLARE @MonitorId CHAR(12);
					EXEC dbo.SysGetObjectPKId '', 'MaterialOverdueMonitor', @MonitorId OUTPUT;
            
					INSERT INTO dbo.MaterialOverdueMonitor
						(MonitorId, ProductName, ProductDescription, VendorName, VendorDescription, ProductionDateCode, LotSN,
						 ResponsiblePerson, CreateDate, MonitorItem, ControlStatus)
					VALUES
						(@MonitorId, @ProductName, @ProductDescription, @VendorName, @VendorDescription, @ProductionDateCode, @LotOrBoxSN, '杜娜娜', GETDATE(), '超周期', '未处理');

					-- 记录日志：插入监控记录成功
					EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '插入监控记录成功';
         
					-- 企业微信推送测试代码
					-- ============================================

					SET @WXMsg = 
						'**超周期物料锁定通知**' + CHAR(10) + CHAR(10) +
						'> 事件类型：<font color="warning">物料锁定</font>' + CHAR(10) +
						'> 料号：' + ISNULL(@ProductName, '') + CHAR(10) +
						'> 物料描述：' + ISNULL(@ProductDescription, '') + CHAR(10) +
						'> 供应商编码：' + ISNULL(@VendorName, '') + CHAR(10) +
						'> 供应商名称：' + ISNULL(@VendorDescription, '') + CHAR(10) +
						'> 生产周期：' + ISNULL(@ProductionDateCode, '') + CHAR(10) +
						'> 批次号：' + ISNULL(@LotOrBoxSN, '') + CHAR(10) +
						'> 锁定原因：<font color="warning">超周期特殊料号303/203锁定</font>' + CHAR(10) +
						'> 锁定时间：' + CONVERT(VARCHAR(20), GETDATE(), 120) + CHAR(10) + CHAR(10) +
						'**请尽快确认处理！**';


					-- 如果没有查到工号，使用默认工号列表
					IF @WXWorkcode = '' OR @WXWorkcode IS NULL
					BEGIN
						SET @WXWorkcode = '1001821,2052731,2080434,1002221';
					END

					-- 调用企业微信推送接口
					EXEC API_SendWXGroupMsg
						@Key = @WXKey,
						@Msg = @WXMsg,  -- 这里才是消息内容
						@Workcode = @WXWorkcode,
						@Type = @WXType,
						@ReturnMessage = @WXReturnMessage OUTPUT;  -- 这是返回结果

					-- 记录日志：推送结果
					EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '========== 推送结果 ==========';

					SET @I_ReturnMessage = '物料超期已被锁定，禁止发料，已通知IQC前往确认3'; -- 逻辑通过

					-- 记录日志：物料被锁定3
					EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '物料超期已被锁定，禁止发料，已通知IQC前往确认3';
					
					RETURN;
				END
			END
			ELSE   -- 非303/203料号开头
			BEGIN
				-- 非特殊料号：直接加入允发名单（修复：补全参数）
				DECLARE @AllowListMessage2 NVARCHAR(100);
				EXEC dbo.AddToAllowList 
					@ProductName = @ProductName,
					@VendorName = @VendorName,
					@VendorDescription = @VendorDescription,
					@ProductionDateCode = @ProductionDateCode,
					@LotSN = @LotOrBoxSN,
					@Message = @AllowListMessage2 OUTPUT;

				-- 企业微信推送代码
				-- ============================================

				SET @WXMsg = 
					'**超周期物料正在发料通知**' + CHAR(10) + CHAR(10) +
					'> 料号：' + ISNULL(@ProductName, '') + CHAR(10) +
					'> 物料描述：' + ISNULL(@ProductDescription, '') + CHAR(10) +
					'> 供应商编码：' + ISNULL(@VendorName, '') + CHAR(10) +
					'> 供应商名称：' + ISNULL(@VendorDescription, '') + CHAR(10) +
					'> 生产周期：' + ISNULL(@ProductionDateCode, '') + CHAR(10) +
					'> 批次号：' + ISNULL(@LotOrBoxSN, '') + CHAR(10) +
					'**请悉知！**';

				-- 如果没有查到工号，使用默认工号列表
				IF @WXWorkcode = '' OR @WXWorkcode IS NULL
				BEGIN
					SET @WXWorkcode = '1001821,2052731,2080434,1002221';
				END

				-- 调用企业微信推送接口
				EXEC API_SendWXGroupMsg
					@Key = @WXKey,
					@Msg = @WXMsg,  -- 这里才是消息内容
					@Workcode = @WXWorkcode,
					@Type = @WXType,
					@ReturnMessage = @WXReturnMessage OUTPUT;  -- 这是返回结果

				-- 记录日志：推送结果
				EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '========== 推送结果 ==========';

				-- 记录日志：已进入6
				EXEC dbo.WriteLog @ProcedureName = 'CheckValidityOverDue', @ProcessMessage = '非特殊料号已加入允发名单';
			END
		END
	END
END
