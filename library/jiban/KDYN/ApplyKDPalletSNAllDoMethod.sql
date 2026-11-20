-- =============================================
-- Author:      <开发团队/个人>
-- Create date: <2026.03.30>
-- Description: <一次性完成订单的栈板申请和箱号绑定，分批申请整板和尾板以确保容量正确>
-- Rev: 1.01
-- =============================================
CREATE PROCEDURE ApplyKDPalletSNAllDoMethod
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
   
    ,@PalletQty INT =0-- 栈板容量 (必填)
    ,@IsFirst BIT=0 -- 是否存在首件箱 (必填)
	,@QtyByBox INT=0 --每箱数量
AS
BEGIN
    -- 基础设置
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- 声明局部变量
    DECLARE @SOName NVARCHAR(50); -- 订单号
    DECLARE @OrderName NVARCHAR(50); -- 订单名称
    DECLARE @OrderQty INT; -- 订单总数
    DECLARE @ActualOrderQty INT; -- 实际需要处理的数量
    DECLARE @ApplyQty INT; -- 需要申请的栈板数量
    DECLARE @FullPalletCount INT; -- 整板数量
    DECLARE @TailPalletQty INT; -- 尾板数量
    DECLARE @ResultCount INT = 0; -- 申请成功的栈板数
    DECLARE @ErrorCount INT = 0; -- 错误计数
    DECLARE @ErrorMessage NVARCHAR(MAX); -- 错误信息
    DECLARE @KDOrderInfoId CHAR(12); -- 订单ID
    DECLARE @ResourceId CHAR(12); -- 资源ID（如果为空则使用默认值）
    
    -- 临时表变量
    DECLARE @BoxList TABLE (
        ID INT IDENTITY(1,1),
        BoxSN NVARCHAR(50) NOT NULL,
        BoxNumber NVARCHAR(100) NULL,
        PalletSN NVARCHAR(50) NULL
    );
    
    DECLARE @PalletList TABLE (
        ID INT IDENTITY(1,1),
        PalletSN NVARCHAR(50) NOT NULL,
        StartBox INT NOT NULL,
        EndBox INT NOT NULL
    );

    -- 初始化输出参数
    SET @I_ReturnMessage = '';
    SET @I_ExceptionFieldName = '';


		IF @I_Sender='DeletePalletSNAll'
		BEGIN
        
			
			DELETE b FROM dbo.KDPalletInfo a WITH(NOLOCK)
			INNER JOIN dbo.ShipPallet b WITH(NOLOCK) ON b.PalletSN = a.PalletSN
			WHERE a.KDOrderInfoId=@I_ParentPKId


			DELETE FROM dbo.KDPalletInfo WHERE KDOrderInfoId=@I_ParentPKId



			SET @I_ReturnMessage = 'ServerMessage: 栈板撤销完成';
            RETURN 0;

		END

    BEGIN TRY
        -- =============================================
        -- 步骤1：验证必填参数
        -- =============================================
        IF @I_ParentPKId IS NULL OR @I_ParentPKId = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 父级主键不能为空';
            RETURN -1;
        END;

        IF @PalletQty <= 0
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 栈板容量必须大于0';
            RETURN -1;
        END;

        -- =============================================
        -- 步骤2：通过父级主键获取订单信息
        -- =============================================
        SELECT 
            @SOName = SOName,
            @OrderName = OrderName,
            @OrderQty = OrderQty,
            @KDOrderInfoId = KDOrderInfoId
        FROM KDOrderInfo
        WHERE KDOrderInfoId = @I_ParentPKId;

	




        IF @SOName IS NULL OR @SOName = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 未找到父级主键对应的订单信息';
            RETURN -1;
        END;

        -- 设置默认资源ID
        SET @ResourceId = ISNULL(@I_ResourceId, 'SRES00000001');

        -- =============================================
        -- 步骤3：计算实际需要处理的数量
        -- =============================================
        SET @ActualOrderQty = @OrderQty;
        IF @IsFirst = 1
        BEGIN
            SET @ActualOrderQty = @ActualOrderQty - 30;
            IF @ActualOrderQty < 0
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage: 订单数量不足30PCS，无法处理首件箱';
                RETURN -1;
            END;
        END;

        -- =============================================
        -- 步骤4：验证申请数量
        -- =============================================
        IF @ApplyQty <= 0
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 申请数量必须大于0';
            RETURN -1;
        END;

        -- =============================================
        -- 步骤5：计算实际需要处理的箱数
        -- =============================================
        SET @FullPalletCount = @ActualOrderQty / (@PalletQty*@QtyByBox);
        SET @TailPalletQty = @ActualOrderQty % (@PalletQty*@QtyByBox);

		PRINT   @FullPalletCount

		IF  @TailPalletQty%@QtyByBox <> 0
		SET @TailPalletQty = @TailPalletQty/@QtyByBox + 1 
		ELSE 
		SET @TailPalletQty = @TailPalletQty/@QtyByBox
		PRINT @TailPalletQty

	    PRINT  @TailPalletQty

		
        -- =============================================
        -- 步骤6：分批申请栈板号（先申请整板，再申请尾板）
        -- =============================================
        -- 申请整板
        IF @FullPalletCount > 0
        BEGIN
            EXEC ApplyKDPalletSNDoMethod
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
                @ApplyQty = @FullPalletCount,
                @PalletQty = @PalletQty;

				PRINT @ErrorMessage
            IF @@ERROR <> 0
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage: 申请整板栈板号失败，错误详情：' + ISNULL(@ErrorMessage, '未知错误');
                RETURN -1;
            END;
        END;

        -- 申请尾板
        IF @TailPalletQty > 0
        BEGIN
            EXEC ApplyKDPalletSNDoMethod
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
                @ApplyQty = 1,
                @PalletQty = @TailPalletQty;

				PRINT @ErrorMessage

            IF @@ERROR <> 0
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage: 申请尾板栈板号失败，错误详情：' + ISNULL(@ErrorMessage, '未知错误');
                RETURN -1;
            END;
        END;

        -- =============================================
        -- 步骤7：获取所有未绑定的箱号
        -- =============================================
        INSERT INTO @BoxList (BoxSN, BoxNumber)
        SELECT 
            BoxSN,
            BoxNumber
        FROM KDBoxInfo
        WHERE KDOrderInfoId = @KDOrderInfoId AND boxsn NOT LIKE 'SJ%'
            AND IsCancel = 0
            AND NOT EXISTS (
                SELECT 1
                FROM ShipPallet
                WHERE ShipPallet.BoxSN = KDBoxInfo.BoxSN
                    AND IsCancel = 0
            )
        ORDER BY BoxSN; -- 按箱号从小到大排序

        IF @@ROWCOUNT = 0
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 未找到需要绑定的箱号';
            RETURN -1;
        END;

        -- =============================================
        -- 步骤8：获取申请的栈板号
        -- =============================================
        -- 计算实际申请的栈板数量
        DECLARE @ActualAppliedQty INT = @FullPalletCount;
        IF @TailPalletQty > 0
        BEGIN
            SET @ActualAppliedQty = @ActualAppliedQty + 1;
        END;

        INSERT INTO @PalletList (PalletSN, StartBox, EndBox)
        SELECT 
            PalletSN,
            0 AS StartBox,
            0 AS EndBox
        FROM KDPalletInfo
        WHERE KDOrderInfoId = @KDOrderInfoId
            AND IsCancel = 0
        ORDER BY PalletSN  -- 按最新申请的栈板号排序
        OFFSET 0 ROWS FETCH NEXT @ActualAppliedQty ROWS ONLY;

        IF @@ROWCOUNT <> @ActualAppliedQty
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 申请的栈板号数量与实际需要的数量不匹配';
            RETURN -1;
        END;

        -- =============================================
        -- 步骤9：计算每个栈板需要绑定的箱号范围
        -- =============================================
        UPDATE @PalletList
        SET 
            StartBox = CASE 
                WHEN ID = 1 THEN 1
                ELSE (ID - 1) * @PalletQty + 1
            END,
            EndBox = CASE 
                WHEN ID = @ActualAppliedQty AND @TailPalletQty > 0 THEN (ID - 1) * @PalletQty + @TailPalletQty
                ELSE ID * @PalletQty
            END;

        -- =============================================
        -- 步骤10：将箱号分配到对应的栈板
        -- =============================================
        UPDATE b
        SET b.PalletSN = p.PalletSN
        FROM @BoxList b
        INNER JOIN @PalletList p ON b.ID BETWEEN p.StartBox AND p.EndBox;

        -- =============================================
        -- 步骤11：绑定栈板和箱号
        -- =============================================
        DECLARE @ShipPalletId CHAR(12); -- 绑定记录ID
        DECLARE @PalletSN NVARCHAR(50); -- 当前处理的栈板号
        DECLARE @BoxSN NVARCHAR(50); -- 当前处理的箱号
        
        -- 声明游标处理每个需要绑定的箱号
        DECLARE BoxCursor CURSOR FOR
        SELECT BoxSN, PalletSN
        FROM @BoxList
        WHERE PalletSN IS NOT NULL
        ORDER BY BoxSN;
        
        OPEN BoxCursor;
        FETCH NEXT FROM BoxCursor INTO @BoxSN, @PalletSN;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- 获取新的ShipPalletId
            EXEC SysGetObjectPKId '', 'ShipPallet', @ShipPalletId OUTPUT;
            
            -- 插入绑定记录
            INSERT INTO ShipPallet (
                ShipPalletId,
                PalletSN,
                BoxSN,
                ResourceId,
                UserId
            ) VALUES (
                @ShipPalletId,
                @PalletSN,
                @BoxSN,
                @ResourceId,
                @I_OrBitUserId
            );
            
            -- 插入原始绑定记录
            EXEC SysGetObjectPKId '', 'OrigShipPallet', @ShipPalletId OUTPUT;
            INSERT INTO OrigShipPallet (
                OrigShipPalletId,
                PalletSN,
                BoxSN,
                ResourceId,
                UserId
            ) VALUES (
                @ShipPalletId,
                @PalletSN,
                @BoxSN,
                @ResourceId,
                @I_OrBitUserId
            );
            
            SET @ResultCount = @ResultCount + 1;
            
            FETCH NEXT FROM BoxCursor INTO @BoxSN, @PalletSN;
        END;
        
        CLOSE BoxCursor;
        DEALLOCATE BoxCursor;

        -- =============================================
        -- 步骤12：返回结果
        -- =============================================
        IF @I_LanguageId = '1'
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 成功申请 ' + CAST(@ApplyQty AS NVARCHAR(10)) + ' 个栈板，并绑定 ' + CAST(@ResultCount AS NVARCHAR(10)) + ' 个箱号';
        END;
        ELSE
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: Successfully applied ' + CAST(@ApplyQty AS NVARCHAR(10)) + ' pallets and bound ' + CAST(@ResultCount AS NVARCHAR(10)) + ' boxes';
        END;

        RETURN 0;

    END TRY
    BEGIN CATCH
        -- 捕获异常并设置返回信息
        SET @ErrorMessage = ERROR_MESSAGE();
        IF @I_LanguageId = '1'
            SET @I_ReturnMessage = 'ServerMessage: 栈板申请和绑定失败，错误详情：' + @ErrorMessage;
        ELSE
            SET @I_ReturnMessage = 'ServerMessage: Pallet application and binding failed, error detail: ' + @ErrorMessage;
        SET @I_ExceptionFieldName = 'SOName'; -- 标记异常关联字段
        RETURN -1; -- 返回错误状态码
    END CATCH;
END;
