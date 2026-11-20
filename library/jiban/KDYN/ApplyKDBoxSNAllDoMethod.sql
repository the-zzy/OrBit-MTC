-- =============================================
-- Author:      <开发团队/个人>
-- Create date: <2026.03.30>
-- Description: <一次性完成订单的所有箱号申请，包括首件箱、整箱和尾箱>
-- Rev: 1.00
-- =============================================
CREATE PROCEDURE ApplyKDBoxSNAllDoMethod
    -- 系统固定接口入参
    @I_Sender NVARCHAR(200) = '', --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT, --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1',          --客户端传入的语言ID(1=中文,2=英文)
    @I_PlugInCommand VARCHAR(5) = '',     --插件命令
    @I_OrBitUserId CHAR(12) = '',         --用户ID
    @I_OrBitUserName NVARCHAR(100) = '',  --用户名
    @I_ResourceId CHAR(12) = '',           --资源ID
    @I_ResourceName NVARCHAR(100) = '',    --资源名
    @I_PKid CHAR(12) = '',                --主键
    @I_ParentPKId CHAR(12) = '',          --父级主键
    @I_Parameter NVARCHAR(100) = ''        --插件参数
    -- 业务自定义入参
    ,@BoxType NVARCHAR(10)='' -- 箱子类别 (必填)
    ,@PCSWeight DECIMAL(18,4)=0 -- 单板重量 (必填)
    ,@QtyByBox INT =0-- 每箱数量 (必填)
    ,@IsFirst BIT =0-- 是否首件箱 (必填)
    ,@BoxLevel NVARCHAR(10)='' -- 箱子层级 (必填)
AS
BEGIN
    -- 基础设置
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- 声明局部变量
    DECLARE @SOName NVARCHAR(50); -- 订单号
    DECLARE @OrderQty INT; -- 订单总数
    DECLARE @RemainingQty INT; -- 剩余数量
    DECLARE @FullBoxCount INT; -- 整箱数量
    DECLARE @TailBoxQty INT; -- 尾箱数量
    DECLARE @TotalBoxCount INT; -- 总箱数
    DECLARE @BoxGrossWeight DECIMAL(18,4); -- 箱子毛重
    DECLARE @NetWeight DECIMAL(18,4); -- 净重
    DECLARE @GrossWeight DECIMAL(18,4); -- 毛重
    DECLARE @ResultCount INT = 0; -- 申请成功的箱数
    DECLARE @ErrorCount INT = 0; -- 错误计数
    DECLARE @ErrorMessage NVARCHAR(MAX); -- 错误信息
    DECLARE @FirstBoxCount INT = 0; -- 首件箱数量
    -- 字符串转换变量
    DECLARE @NWeightStr NVARCHAR(50); -- 字符串类型的净重
    DECLARE @GWeightStr NVARCHAR(50); -- 字符串类型的毛重
    DECLARE @QtyByBoxStr NVARCHAR(50); -- 字符串类型的每箱数量
    DECLARE @ApplyQtyStr NVARCHAR(50); -- 字符串类型的申请数量

    -- 初始化输出参数
    SET @I_ReturnMessage = '';
    SET @I_ExceptionFieldName = '';

    BEGIN TRY
        -- =============================================
        -- 步骤1：验证必填参数
        -- =============================================
        IF @I_ParentPKId IS NULL OR @I_ParentPKId = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 父级主键不能为空';
            RETURN -1;
        END;

        -- =============================================
        -- 步骤2：通过父级主键获取订单号
        -- =============================================
        SELECT @SOName = SOName
        FROM KDOrderInfo
        WHERE KDOrderInfoId = @I_ParentPKId;


		IF  @I_Sender='DeleteBoxSNAll'
		BEGIN
			DELETE FROM dbo.KDBoxInfo WHERE KDOrderInfoId = @I_ParentPKId
			DELETE FROM dbo.KDBoxItem WHERE KDOrderInfoId = @I_ParentPKId
			
			 SET @I_ReturnMessage = 'ServerMessage: 箱号全部撤销完成';
            RETURN 0;
		END



        IF @SOName IS NULL OR @SOName = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 未找到父级主键对应的订单信息';
            RETURN -1;
        END;

        -- =============================================
        -- 步骤3：获取订单总数
        -- =============================================
        SELECT @OrderQty = OrderQty
        FROM KDOrderInfo
        WHERE KDOrderInfoId = @I_ParentPKId;

        IF @OrderQty IS NULL
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 未找到订单 ' + @SOName + ' 的信息';
            RETURN -1;
        END;

        -- =============================================
        -- 步骤3：获取箱子毛重
        -- =============================================
        SELECT @BoxGrossWeight = GrossWeight
        FROM KDBoxType a INNER JOIN dbo.KDBoxTypeItem b ON b.KDBoxTypeId = a.KDBoxTypeId
        WHERE BoxType = @BoxType;

        IF @BoxGrossWeight IS NULL
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 未找到箱子类型 ' + @BoxType + ' 的信息';
            RETURN -1;
        END;

        -- =============================================
        -- 步骤4：计算首件箱相关
        -- =============================================
        SET @RemainingQty = @OrderQty;

		PRINT  @IsFirst



        IF @IsFirst = 1
        BEGIN
            -- 扣减首件箱的30PCS
            SET @RemainingQty = @RemainingQty - 30;
            SET @FirstBoxCount = 1;



            -- 验证剩余数量是否足够
            IF @RemainingQty < 0
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage: 订单数量不足30PCS，无法创建首件箱';
                RETURN -1;
            END;

		
   --         -- 计算首件箱的净重和毛重
   --         SET @NetWeight = @PCSWeight * 30; -- 首件箱30PCS
   --         SET @GrossWeight = @NetWeight + @BoxGrossWeight;

   --         -- 转换为字符串类型
   --         SET @NWeightStr = CAST(@NetWeight AS NVARCHAR(50));
   --         SET @GWeightStr = CAST(@GrossWeight AS NVARCHAR(50));
   --         SET @QtyByBoxStr = CAST(30 AS NVARCHAR(50));
   --         SET @ApplyQtyStr = CAST(1 AS NVARCHAR(50));

			--PRINT  @NWeightStr
			--PRINT @GWeightStr
			--PRINT   @QtyByBoxStr
			--PRINT @ApplyQtyStr
			--PRINT   @I_ParentPKId
			--PRINT  @I_PKid

	

   --         -- 申请首件箱
   --         EXEC ApplyKDBoxSNDoMethod
   --             @I_Sender = @I_Sender,
   --             @I_ReturnMessage = @ErrorMessage OUTPUT,
   --             @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
   --             @I_LanguageId = @I_LanguageId,
   --             @I_PlugInCommand = @I_PlugInCommand,
   --             @I_OrBitUserId = @I_OrBitUserId,
   --             @I_OrBitUserName = @I_OrBitUserName,
   --             @I_ResourceId = @I_ResourceId,
   --             @I_ResourceName = @I_ResourceName,
   --             @I_PKid = @I_PKid,
   --             @I_ParentPKId = @I_ParentPKId,
   --             @I_Parameter = @I_Parameter,
   --             @BoxLevel = 'A0', -- 首件箱固定BoxLevel值
   --             @BoxType = '5A', -- 首件箱固定BoxType值
   --             @Length = NULL, -- 长度
   --             @Width = NULL, -- 宽度
   --             @Height = NULL, -- 高度
   --             @NWeight = @NWeightStr, -- 净重 (字符串类型)
   --             @GWeight = @GWeightStr, -- 毛重 (字符串类型)
   --             @QtyByBox = @QtyByBoxStr, -- 每箱数量 (字符串类型)
   --             @ApplyQty = @ApplyQtyStr, -- 申请数量（1箱）
   --             @IsFirst = 1; -- 是否首件箱

			--	PRINT  @ErrorMessage

   --         IF @@ERROR = 0
   --             SET @ResultCount = @ResultCount + 1;
   --         ELSE
   --             SET @ErrorCount = @ErrorCount + 1;
        END;

        -- =============================================
        -- 步骤5：计算整箱和尾箱
        -- =============================================
        -- 整箱数量 = 剩余数量 / 每箱数量
        SET @FullBoxCount = @RemainingQty / @QtyByBox;
        -- 尾箱数量 = 剩余数量 % 每箱数量
        SET @TailBoxQty = @RemainingQty % @QtyByBox;

		PRINT  @FullBoxCount
		PRINT @TailBoxQty

        -- 计算整箱的净重和毛重
        SET @NetWeight = @PCSWeight * @QtyByBox;
        SET @GrossWeight = @NetWeight + @BoxGrossWeight;

        -- 转换为字符串类型
        SET @NWeightStr = CAST(@NetWeight AS NVARCHAR(50));
        SET @GWeightStr = CAST(@GrossWeight AS NVARCHAR(50));
        SET @QtyByBoxStr = CAST(@QtyByBox AS NVARCHAR(50));
        SET @ApplyQtyStr = CAST(1 AS NVARCHAR(50));

        -- =============================================
        -- 步骤6：申请整箱
        -- =============================================
        WHILE @FullBoxCount > 0
        BEGIN
            EXEC ApplyKDBoxSNDoMethod
                @I_Sender = @I_Sender,
                @I_ReturnMessage = @ErrorMessage OUTPUT,
                @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
                @I_LanguageId = @I_LanguageId,
                @I_PlugInCommand = @I_PlugInCommand,
                @I_OrBitUserId = @I_OrBitUserId,
                @I_OrBitUserName = @I_OrBitUserName,
                @I_ResourceId = @I_ResourceId,
                @I_ResourceName = @I_ResourceName,
                @I_PKid = @I_PKid,
                @I_ParentPKId = @I_ParentPKId,
                @I_Parameter = @I_Parameter,
                @BoxLevel = @BoxLevel,
                @BoxType = @BoxType,
                @Length = NULL,
                @Width = NULL,
                @Height = NULL,
                @NWeight = @NWeightStr,
                @GWeight = @GWeightStr,
                @QtyByBox = @QtyByBoxStr,
                @ApplyQty = @ApplyQtyStr,
                @IsFirst = 0;
				PRINT @ErrorMessage

            IF @@ERROR = 0
                SET @ResultCount = @ResultCount + 1;
            ELSE
                SET @ErrorCount = @ErrorCount + 1;

            SET @FullBoxCount = @FullBoxCount - 1;
        END;

        -- =============================================
        -- 步骤7：申请尾箱
        -- =============================================
        IF @TailBoxQty > 0
        BEGIN
            -- 计算尾箱的净重和毛重
            SET @NetWeight = @PCSWeight * @TailBoxQty;
            SET @GrossWeight = @NetWeight + @BoxGrossWeight;

            -- 转换为字符串类型
            SET @NWeightStr = CAST(@NetWeight AS NVARCHAR(50));
            SET @GWeightStr = CAST(@GrossWeight AS NVARCHAR(50));
            SET @QtyByBoxStr = CAST(@TailBoxQty AS NVARCHAR(50));
            SET @ApplyQtyStr = CAST(1 AS NVARCHAR(50));

            EXEC ApplyKDBoxSNDoMethod
                @I_Sender = @I_Sender,
                @I_ReturnMessage = @ErrorMessage OUTPUT,
                @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
                @I_LanguageId = @I_LanguageId,
                @I_PlugInCommand = @I_PlugInCommand,
                @I_OrBitUserId = @I_OrBitUserId,
                @I_OrBitUserName = @I_OrBitUserName,
                @I_ResourceId = @I_ResourceId,
                @I_ResourceName = @I_ResourceName,
                @I_PKid = @I_PKid,
                @I_ParentPKId = @I_ParentPKId,
                @I_Parameter = @I_Parameter,
                @BoxLevel = @BoxLevel,
                @BoxType = @BoxType,
                @Length = NULL,
                @Width = NULL,
                @Height = NULL,
                @NWeight = @NWeightStr,
                @GWeight = @GWeightStr,
                @QtyByBox = @QtyByBoxStr,
                @ApplyQty = @ApplyQtyStr,
                @IsFirst = 0;

				PRINT @ErrorMessage

            IF @@ERROR = 0
                SET @ResultCount = @ResultCount + 1;
            ELSE
                SET @ErrorCount = @ErrorCount + 1;
        END;



		        IF @IsFirst = 1
        BEGIN
   

            -- 计算首件箱的净重和毛重
            SET @NetWeight = @PCSWeight * 30; -- 首件箱30PCS
            SET @GrossWeight = @NetWeight + @BoxGrossWeight;

            -- 转换为字符串类型
            SET @NWeightStr = CAST(@NetWeight AS NVARCHAR(50));
            SET @GWeightStr = CAST(@GrossWeight AS NVARCHAR(50));
            SET @QtyByBoxStr = CAST(30 AS NVARCHAR(50));
            SET @ApplyQtyStr = CAST(1 AS NVARCHAR(50));

			PRINT  @NWeightStr
			PRINT @GWeightStr
			PRINT   @QtyByBoxStr
			PRINT @ApplyQtyStr
			PRINT   @I_ParentPKId
			PRINT  @I_PKid

	

            -- 申请首件箱
            EXEC ApplyKDBoxSNDoMethod
                @I_Sender = @I_Sender,
                @I_ReturnMessage = @ErrorMessage OUTPUT,
                @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
                @I_LanguageId = @I_LanguageId,
                @I_PlugInCommand = @I_PlugInCommand,
                @I_OrBitUserId = @I_OrBitUserId,
                @I_OrBitUserName = @I_OrBitUserName,
                @I_ResourceId = @I_ResourceId,
                @I_ResourceName = @I_ResourceName,
                @I_PKid = @I_PKid,
                @I_ParentPKId = @I_ParentPKId,
                @I_Parameter = @I_Parameter,
                @BoxLevel = 'A0', -- 首件箱固定BoxLevel值
                @BoxType = '5A', -- 首件箱固定BoxType值
                @Length = NULL, -- 长度
                @Width = NULL, -- 宽度
                @Height = NULL, -- 高度
                @NWeight = @NWeightStr, -- 净重 (字符串类型)
                @GWeight = @GWeightStr, -- 毛重 (字符串类型)
                @QtyByBox = @QtyByBoxStr, -- 每箱数量 (字符串类型)
                @ApplyQty = @ApplyQtyStr, -- 申请数量（1箱）
                @IsFirst = 1; -- 是否首件箱

				PRINT  @ErrorMessage

            IF @@ERROR = 0
                SET @ResultCount = @ResultCount + 1;
            ELSE
                SET @ErrorCount = @ErrorCount + 1;
        END;

        -- =============================================
        -- 步骤8：计算总箱数并返回结果
        -- =============================================
        SET @TotalBoxCount = @FirstBoxCount + (@OrderQty - @RemainingQty - @FirstBoxCount * 30) / @QtyByBox + CASE WHEN @TailBoxQty > 0 THEN 1 ELSE 0 END;



		IF  @IsFirst= 1
		BEGIN
        
				-- 自动扣减 首件的 30台 
			UPDATE  dbo.KDOrderItem SET ItemQtyRequired = ItemQtyRequired - 30 WHERE KDOrderItemId = @I_PKid



		END

        -- 返回成功消息
        IF @I_LanguageId = '1'
        BEGIN
            IF @ErrorCount = 0
                SET @I_ReturnMessage = 'ServerMessage: 成功申请 ' + CAST(@ResultCount AS NVARCHAR(10)) + ' 个箱号，共 ' + CAST(@TotalBoxCount AS NVARCHAR(10)) + ' 箱';
            ELSE
                SET @I_ReturnMessage = 'ServerMessage: 部分箱号申请失败，成功 ' + CAST(@ResultCount AS NVARCHAR(10)) + ' 个，失败 ' + CAST(@ErrorCount AS NVARCHAR(10)) + ' 个';
        END;
        ELSE
        BEGIN
            IF @ErrorCount = 0
                SET @I_ReturnMessage = 'ServerMessage: Successfully applied ' + CAST(@ResultCount AS NVARCHAR(10)) + ' box SNs, total ' + CAST(@TotalBoxCount AS NVARCHAR(10)) + ' boxes';
            ELSE
                SET @I_ReturnMessage = 'ServerMessage: Partial application failed, success ' + CAST(@ResultCount AS NVARCHAR(10)) + ', failed ' + CAST(@ErrorCount AS NVARCHAR(10));
        END;

        RETURN 0;

    END TRY
    BEGIN CATCH
        -- 捕获异常并设置返回信息
        SET @ErrorMessage = ERROR_MESSAGE();
        IF @I_LanguageId = '1'
            SET @I_ReturnMessage = 'ServerMessage: 箱号申请失败，错误详情：' + @ErrorMessage;
        ELSE
            SET @I_ReturnMessage = 'ServerMessage: Box SN application failed, error detail: ' + @ErrorMessage;
        SET @I_ExceptionFieldName = 'SOName'; -- 标记异常关联字段
        RETURN -1; -- 返回错误状态码
    END CATCH;
END;
