
-- =============================================
-- Author:		<Wang RT>
-- Create date: <2020.7.8>
-- Description:	申请散件外箱号
-- =============================================
CREATE PROCEDURE [dbo].[ApplyKDBoxSNDoMethod_New]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKid CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = ',' ,		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @BoxLevel NVARCHAR(20) = '' ,          --箱号层级
    @BoxType NVARCHAR(20) = '' ,           --箱号类别
    @Length NVARCHAR(50) = '' ,            --长
    @Width NVARCHAR(50) = '' ,             --宽
    @Height NVARCHAR(50) = '' ,            --高
    @NWeight NVARCHAR(50) = '' ,           --净重
    @GWeight NVARCHAR(50) = '' ,           --毛重
    @QtyByBox NVARCHAR(50) = '' ,          --每箱数量
    @ApplyQty NVARCHAR(50) = '' ,          --申请箱数
	@IsFirst BIT=0                         --是否首件
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
			
    DECLARE @return_value INT;
    SET @return_value = -1;

	--检查元对象方法用户授权
    EXEC @return_value= [dbo].[MetadataPermissionCheckDoMethod]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @I_OrBitUserId = @I_OrBitUserId ,
        @I_OrBitUserName = @I_OrBitUserName ,
        @I_Sender = @I_Sender;

    IF @return_value = -1
    BEGIN
        SET @I_ReturnMessage = @I_ReturnMessage;
        RETURN -1;
    END;

    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @KDBoxInfoId CHAR(12);
    DECLARE @OrderName NVARCHAR(50);
    DECLARE @MaxBoxSN NVARCHAR(50);
    DECLARE @MaxBoxBit INT;
    DECLARE @BoxSN NVARCHAR(50);
    DECLARE @BoxNumber NVARCHAR(50);
    DECLARE @BoxCounter INT;
    DECLARE @k INT;
    DECLARE @FirstBoxSN NVARCHAR(50);
    DECLARE @LastBoxSN NVARCHAR(50);

    DECLARE @BoxLength DECIMAL(18, 2);
    DECLARE @BoxWidth DECIMAL(18, 2);
    DECLARE @BoxHeight DECIMAL(18, 2);
    DECLARE @NetWeight DECIMAL(18, 2);
    DECLARE @GrossWeight DECIMAL(18, 2);
    DECLARE @BoxLotQty DECIMAL(18, 2);
    DECLARE @ApplyBoxQty INT;
    DECLARE @ProductId CHAR(12);
    DECLARE @ProductName NVARCHAR(50);
    DECLARE @KDOrderItemId CHAR(12);
    DECLARE @KDBoxItemId CHAR(12);
    DECLARE @IsPackQty DECIMAL(18, 2);
    DECLARE @ItemQtyRequired DECIMAL(18, 2);
    DECLARE @ModuleName NVARCHAR(50);
    DECLARE @QtyPack DECIMAL(18, 2);

    SET @KDOrderInfoId = '';
    SET @KDBoxInfoId = '';
    SET @OrderName = '';
    SET @MaxBoxSN = '';
    SET @MaxBoxBit = 0;
    SET @BoxNumber = '';
    SET @BoxSN = '';
    SET @BoxCounter = 0;
    SET @k = 0;

    SET @BoxLength = 0;
    SET @BoxWidth = 0;
    SET @BoxHeight = 0;
    SET @NetWeight = 0;
    SET @GrossWeight = 0;
    SET @BoxLotQty = 0;
    SET @ApplyBoxQty = 0;
    SET @ProductId = '';
    SET @KDOrderItemId = '';
    SET @KDBoxItemId = '';
    SET @ProductName = '';
    SET @IsPackQty = 0;
    SET @ItemQtyRequired = 0;
    SET @ModuleName = '';
    SET @QtyPack = 0;

	DECLARE @CounterType NVARCHAR(200) = ''

    DECLARE @Temp TABLE
        (
          ProductId CHAR(12) ,
          ModuleName NVARCHAR(50) ,
          QtyPack DECIMAL(18, 2)
        );

	IF ISNULL(@BoxType,'') = 'SL'
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage:箱号类别不能为SL!';
        RETURN -1;
	END

    IF ISNULL(@I_ParentPKId, '') = '' OR ISNULL(@I_PKid, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择有效行项!';
        RETURN -1;
    END;

    IF ISNULL(@BoxLevel, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入箱号层级!';
        RETURN -1;
    END;

    IF ISNULL(@BoxType, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入箱号类别!';
        RETURN -1;
    END;

    IF ISNULL(@Length, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入长度!';
        RETURN -1;
    END;

    IF ISNULL(@Width, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入宽度!';
        RETURN -1;
    END;

    IF ISNULL(@Height, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入高度!';
        RETURN -1;
    END;

    IF ISNULL(@NWeight, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入净重!';
        RETURN -1;
    END;

    IF ISNULL(@GWeight, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入毛重!';
        RETURN -1;
    END;

    IF ISNULL(@QtyByBox, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入每箱数量!';
        RETURN -1;
    END;

    IF ISNULL(@ApplyQty, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入申请箱数!';
        RETURN -1;
    END;

    SET @BoxLength = CONVERT(FLOAT, @Length);
    SET @BoxWidth = CONVERT(FLOAT, @Width);
    SET @BoxHeight = CONVERT(FLOAT, @Height);
    SET @NetWeight = CONVERT(FLOAT, @NWeight);
    SET @GrossWeight = CONVERT(FLOAT, @GWeight);
    SET @BoxLotQty = CONVERT(FLOAT, @QtyByBox);
    SET @ApplyBoxQty = CONVERT(FLOAT, @ApplyQty);

    IF ISNULL(@BoxLength, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:外箱长度必须大于零!';
        RETURN -1;
    END;

    IF ISNULL(@BoxWidth, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:外箱宽度必须大于零!';
        RETURN -1;
    END;

    IF ISNULL(@BoxHeight, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:外箱高度必须大于零!';
        RETURN -1;
    END;

    IF ISNULL(@NetWeight, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:外箱净重必须大于零!';
        RETURN -1;
    END;

    IF ISNULL(@GrossWeight, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:外箱毛重必须大于零!';
        RETURN -1;
    END;

    IF ISNULL(@BoxLotQty, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:每箱数量必须大于零!';
        RETURN -1;
    END;

    IF ISNULL(@ApplyBoxQty, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:申请箱数必须大于零!';
        RETURN -1;
    END;

    IF @BoxLevel NOT IN ( 'A0', 'A2', 'A4' )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:外箱层级必须是 A0/A2/A4 !';
        RETURN -1;
    END;

	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.KDBoxType WHERE BoxType = @BoxType )
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage:箱号类别不存在!';
        RETURN -1;
	END

	--获取订单信息
    SELECT  @KDOrderInfoId = KDOrderInfoId, @OrderName = OrderName--, @BoxCounter = BoxCounter
    FROM    KDOrderInfo
    WHERE   KDOrderInfoId = @I_ParentPKId;

	--获取组件号
    SELECT  @KDOrderItemId = KDOrderItem.KDOrderItemId, @ModuleName = KDOrderItem.ModuleName
    FROM    KDOrderItem
    WHERE   KDOrderInfoId = @KDOrderInfoId AND KDOrderItemId = @I_PKid AND IsIgnore = 0 AND IsValidity = 1;

	--记录组件下的物料ID
    INSERT  INTO @Temp ( ProductId, ModuleName, QtyPack )
            SELECT  ProductId, ModuleName, QtyPack
            FROM    KDOrderItem
            WHERE   KDOrderInfoId = @KDOrderInfoId AND ModuleName = @ModuleName AND IsIgnore = 0 AND IsValidity = 1;

    IF ISNULL(@KDOrderInfoId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:未找到订单号!';
        RETURN -1;
    END;

    IF ISNULL(@KDOrderItemId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:未找到订单行或者订单行无效!';
        RETURN -1;
    END;

	--游标写入数据
    DECLARE cursor1 CURSOR
    FOR
    SELECT  ProductId, ModuleName, QtyPack
    FROM    @Temp;
    OPEN cursor1;
    FETCH NEXT FROM cursor1 
	INTO @ProductId, @ModuleName, @QtyPack;
    WHILE @@FETCH_STATUS = 0
    BEGIN	
		--已包装数
        SET @IsPackQty = 0;
        SELECT  @IsPackQty = ISNULL(SUM(RealQty), 0)
        FROM    KDBoxItem
        WHERE   KDOrderInfoId = @KDOrderInfoId AND ModuleName = @ModuleName AND KDBoxItem.ProductId = @ProductId AND IsCancel = 0;

		--需求数
        SET @ItemQtyRequired = 0;
        SELECT  @ItemQtyRequired = ISNULL(KDOrderItem.ItemQtyRequired, 0)
        FROM    KDOrderItem
        INNER JOIN KDOrderInfo ON KDOrderInfo.KDOrderInfoId = KDOrderItem.KDOrderInfoId
        WHERE   KDOrderInfo.KDOrderInfoId = @KDOrderInfoId AND KDOrderItem.ModuleName = @ModuleName AND KDOrderItem.ProductId = @ProductId AND IsIgnore = 0 AND IsValidity = 1;

        SET @ProductName = '';
        SELECT  @ProductName = ProductRoot.ProductName
        FROM    Product
        INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
        WHERE   Product.ProductId = @ProductId;

        --IF @IsPackQty + ( @BoxLotQty * @ApplyBoxQty ) > @ItemQtyRequired
        --BEGIN
        --    SET @I_ReturnMessage = 'ServerMessage:物料 [' + @ProductName + '] 已包装数 [' + CAST(@IsPackQty AS VARCHAR) + '] 加上当前包装数 [' + CAST(( @BoxLotQty * @ApplyBoxQty ) AS VARCHAR) + '] 已超出需求数 [' + CAST(@ItemQtyRequired AS VARCHAR) + '] ，申请失败!';
        --    RETURN -1;
        --END;
	
        FETCH NEXT FROM cursor1 
		INTO @ProductId, @ModuleName, @QtyPack;
    END;
    CLOSE cursor1;
    DEALLOCATE cursor1; 

    WHILE ( @k < @ApplyBoxQty )
    BEGIN
        SET @k = @k + 1;

		--获取同一类别最大的一个箱号
        IF EXISTS ( SELECT  1
                    FROM    KDBoxInfo
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxType = @BoxType AND IsCancel = 0 )
        BEGIN
            SELECT  @MaxBoxBit = ISNULL(MAX(CONVERT(INT, SUBSTRING(BoxNumber, CHARINDEX('/', BoxNumber) + 1,
                                                                   LEN(BoxNumber)))), 0)
            FROM    KDBoxInfo
            WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxType = @BoxType AND KDBoxInfo.IsCancel = 0;
        END;
        ELSE
            SET @MaxBoxBit = 0;

        --SET @BoxCounter = @BoxCounter + 1;
        --SET @BoxSN = @BoxType + 'XH' + REPLACE(@OrderName,'-','#') + [dbo].[Convert10ToDecimal](@BoxCounter, 5, 10);
		SET @CounterType = @BoxType + 'XH' + @OrderName

		EXEC dbo.TxnBase_GetSNCounter
		    @SNCounterName = N'KDOI自动生成箱号' , -- nvarchar(50)
		    @CounterType = @CounterType , -- nvarchar(50)
		    @OwnerId = N'' , -- nvarchar(30)
		    @Year = '' , -- char(4)
		    @Month = '' , -- char(2)
		    @Week = '' , -- char(2)
		    @Day = '' , -- char(2)
		    @SNCounter = @BoxCounter OUTPUT -- bigint

		SET @BoxSN = @BoxType + 'XH' + REPLACE(@OrderName,'-','#') + RIGHT('00000' + CAST(@BoxCounter AS VARCHAR(50)),5)

        SET @MaxBoxBit = ISNULL(@MaxBoxBit, 0) + 1;
        SET @BoxNumber = @BoxType + '/' + CAST(@MaxBoxBit AS VARCHAR);

        IF EXISTS ( SELECT  1
                    FROM    KDBoxInfo
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @BoxNumber AND IsCancel = 0 )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:申请的外箱编号 [' + @BoxNumber + '] 重复,请重新申请!';
            RETURN -1;
        END;

        IF EXISTS ( SELECT  1
                    FROM    KDBoxInfo
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxSN = @BoxSN AND IsCancel = 0 )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:申请的箱号 [' + @BoxSN + '] 重复,请重新申请!';
            RETURN -1;
        END;

		--首箱
        IF @k = 1
            SET @FirstBoxSN = @BoxNumber;

		--尾箱
        IF @k = @ApplyBoxQty
            SET @LastBoxSN = @BoxNumber;

		--更新箱号计数器
        UPDATE  KDOrderInfo
        SET     BoxCounter = BoxCounter + 1
        WHERE   KDOrderInfoId = @KDOrderInfoId;

        EXEC SysGetObjectPKId
            '' ,
            'KDBoxInfo' ,
            @KDBoxInfoId OUTPUT;
        INSERT  INTO KDBoxInfo ( KDBoxInfoId, KDOrderInfoId, OrderName, BoxSN, BoxNumber, BoxLevel, BoxType, BoxLength,
                                 BoxWidth, BoxHeight, NetWeight, GrossWeight, CreateUserId )
        VALUES  ( @KDBoxInfoId, @KDOrderInfoId, @OrderName, @BoxSN, @BoxNumber, @BoxLevel, @BoxType, @BoxLength,
                  @BoxWidth, @BoxHeight, @NetWeight, @GrossWeight, @I_OrBitUserId );

        DECLARE cursor2 CURSOR
        FOR
        SELECT  ProductId, QtyPack
        FROM    @Temp;
        OPEN cursor2;
        FETCH NEXT FROM cursor2 
		INTO @ProductId, @QtyPack;
        WHILE @@FETCH_STATUS = 0
        BEGIN	

            EXEC SysGetObjectPKId
                '' ,
                'KDBoxItem' ,
                @KDBoxItemId OUTPUT;
            INSERT  INTO KDBoxItem ( KDBoxItemId, KDOrderInfoId, KDBoxInfoId, ModuleName, ProductId, RealQty,
                                     CreateUserId )
            VALUES  ( @KDBoxItemId, @KDOrderInfoId, @KDBoxInfoId, @ModuleName, @ProductId, @BoxLotQty, @I_OrBitUserId );

            FETCH NEXT FROM cursor2 
			INTO @ProductId, @QtyPack;
        END;
        CLOSE cursor2;
        DEALLOCATE cursor2; 

    END;

    SET @I_ReturnMessage = 'ServerMessage:申请箱号成功!共 [' + CAST(@k AS VARCHAR) + '] 箱. 从 [' + @FirstBoxSN + '] 到 [' + @LastBoxSN + ']!';
    RETURN 0;
END;









