
-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016.08.02>
-- Description:	同步BOMItem数据
-- =============================================
CREATE PROCEDURE [dbo].[KDOrderExpandItemFromTVDoMethod]
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
    @I_Parameter NVARCHAR(100) = ''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
		
    DECLARE @return_value INT;
    SET @return_value = -1;

	----检查元对象方法用户授权
 --   EXEC @return_value= [dbo].[MetadataPermissionCheckDoMethod]
 --       @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
 --       @I_OrBitUserId = @I_OrBitUserId ,
 --       @I_OrBitUserName = @I_OrBitUserName ,
 --       @I_Sender = @I_Sender;

 --   IF @return_value = -1
 --   BEGIN
 --       SET @I_ReturnMessage = @I_ReturnMessage;
 --       RETURN -1;
 --   END;
	
	IF @I_OrBitUserName NOT IN('SC3902', '2061399')
	BEGIN
    
		SET @I_ReturnMessage='ServerMessage: 无权操作'
		RETURN -1;
	END
    


    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @MOId CHAR(12);
    DECLARE @MProductName NVARCHAR(50);
    DECLARE @MProductDescription NVARCHAR(200);
    DECLARE @MOName NVARCHAR(50);
    DECLARE @MProductId CHAR(12);
    DECLARE @BOMId CHAR(12);
    DECLARE @CustomerNumber NVARCHAR(50);
    DECLARE @ModuleName NVARCHAR(50);
    DECLARE @EnglishDescription NVARCHAR(500);
    DECLARE @KDOrderItemId CHAR(12);
    DECLARE @KDMOId CHAR(12);
    DECLARE @LineSequence NVARCHAR(30);
    DECLARE @OrderName NVARCHAR(50);
    DECLARE @MOProductId CHAR(12);
    DECLARE @MOProductName NVARCHAR(50);
    DECLARE @IsIgnore BIT;
    DECLARE @IsAdd BIT= 0;
    DECLARE @IsExpand BIT;
    DECLARE @BOMQtyRequired DECIMAL(18, 2);
    DECLARE @QtyPack DECIMAL(18, 2);
    DECLARE @UOMId CHAR(12);
    DECLARE @MOPackQty DECIMAL(18, 2);
    DECLARE @ItemQtyRequired DECIMAL(18, 4);
    DECLARE @IsBom BIT= 0;				--1是BOM里面的品号,0工单里面的品号
    DECLARE @FieldsA NVARCHAR(500)= '';		  --附件字段A
    DECLARE @FieldsB NVARCHAR(500)= '';			  --附件字段B
    DECLARE @SingleWeight DECIMAL(18, 4)= 0;         --单机重量
    DECLARE @SOName VARCHAR(20) = '';
    DECLARE @MOItemId CHAR(12);
    DECLARE @KDMOItemId CHAR(12);
    DECLARE @MOItemQtyRequired DECIMAL(18, 4);
    DECLARE @MSOName NVARCHAR(50);

	
    SET @KDOrderInfoId = '';
    SET @MOId = '';
    SET @MProductName = '';
    SET @MProductDescription = '';
    SET @MOName = '';
    SET @MProductId = '';
    SET @BOMId = '';
    SET @CustomerNumber = '';
    SET @ModuleName = '';
    SET @EnglishDescription = '';
    SET @KDOrderItemId = '';
    SET @LineSequence = '';
    SET @OrderName = '';
    SET @MOProductId = '';
    SET @MOProductName = '';
    SET @IsIgnore = 0;
    SET @IsExpand = 0;
    SET @BOMQtyRequired = 0;
    SET @QtyPack = 0;
    SET @UOMId = '';
    SET @MOPackQty = 0;
    SET @ItemQtyRequired = 0;

    DECLARE @TempMO TABLE
        (
          MOId CHAR(12) ,
          IsExpand BIT ,
          MOPackQty DECIMAL(18, 2)
        );

    IF ISNULL(@I_PKid, '') = '' OR ISNULL(@I_ParentPKId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择有效行项!';
        RETURN -1;
    END;


	--获取散件订单信息
    SELECT  @KDOrderInfoId = KDOrderInfoId, @OrderName = OrderName, @SOName = SOName
    FROM    KDOrderInfo
    WHERE   KDOrderInfoId = @I_ParentPKId;

	CREATE TABLE #tmpSyncMOForCKDYN
	(
		id INT IDENTITY(1,1),
		[moname] [nvarchar] (50),
		[isSync] [nvarchar] (50),
		[isExpand] [nvarchar] (50) ,
		[createdate] [datetime] 
	) 

	DECLARE @pkid TABLE(
		seq INT,
		pkid CHAR(12)
	)

	DECLARE @row INT;

	INSERT INTO #tmpSyncMOForCKDYN(moname,isSync,isExpand,createdate)
	SELECT DISTINCT a.moname,issync,isExpand,a.createdate
	 FROM SyncMOForCKDYN a INNER JOIN mo b ON  b.MOName = a.moname WHERE isSync =0

	 SELECT @row = COUNT(*) FROM #tmpSyncMOForCKDYN


	 IF @row = 0
	 BEGIN
		SET @I_ReturnMessage ='ServerMessage: 无数据需要同步'
		RETURN -1;

	 END
     

	 INSERT INTO @pkid
	 EXEC dbo.SysGetObjectPKIdBatch @ObjectId = '',    -- char(12)
	                                @ObjectName = N'KDMO', -- nvarchar(100)
	                                @RowCount = @row     -- int
	 



		--同步TV工单
	INSERT INTO dbo.KDMO
	(
	    KDMOId,
	    KDOrderInfoId,
	    MOId,
	    MOPackQty,
	    IsExpand,
	    CreateDate
	)
	SELECT c.pkid,@KDOrderInfoId, b.MOId,b.MOQtyRequired,0,GETDATE()
	 FROM #tmpSyncMOForCKDYN a INNER JOIN dbo.MO b ON b.MOName = a.moname
	 INNER JOIN @pkid c ON c.seq=a.id
	 WHERE a.isSync =0
     
	 UPDATE b
	 SET b.isSync = 1 
	 FROM #tmpSyncMOForCKDYN a INNER JOIN dbo.SyncMOForCKDYN b ON b.moname = a.moname




    INSERT  INTO @TempMO ( MOId, IsExpand, MOPackQty )
            SELECT  MOId, IsExpand, MOPackQty
            FROM    KDMO
            WHERE   KDOrderInfoId = @KDOrderInfoId AND IsExpand =0

    UPDATE @TempMO SET IsExpand = 1 


    IF NOT EXISTS ( SELECT  1
                    FROM    @TempMO )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:订单未找到任何工单!';
        RETURN -1;
    END;

	--如果存在组件数据，则提示先清除组件数据
	--if exists(select 1 from KDOrderItem where KDOrderInfoId=@KDOrderInfoId)
	--begin
	--	set @I_ReturnMessage='ServerMessage:当前订单存在组件数据，重新 [展开工单明细] 前，请先执行 [清除组件数据].'
	--	return -1
	--end

	--游标写入数据
    DECLARE cursor5 CURSOR
    FOR
    SELECT  MOId, IsExpand, MOPackQty
    FROM    @TempMO;
    OPEN cursor5;
    FETCH NEXT FROM cursor5 
	INTO @MOId, @IsExpand, @MOPackQty;
    WHILE @@FETCH_STATUS = 0
    BEGIN	
        SET @MOName = '';
        SELECT  @MOName = MOName
        FROM    MO
        WHERE   MOId = @MOId;

        IF ISNULL(@MOPackQty, 0) <= 0
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:工单 [' + @MOName + '] 未维护包装数，请检查!';
            RETURN -1;
        END;

        FETCH NEXT FROM cursor5 
		INTO @MOId, @IsExpand, @MOPackQty;
    END;
    CLOSE cursor5;
    DEALLOCATE cursor5; 


	--先更新非手动添加的所有的需求数量为零
    UPDATE  KDOrderItem
    SET     ItemQtyRequired = 0
    WHERE   KDOrderInfoId = @KDOrderInfoId AND IsAdd = 0;

	--游标写入数据
    DECLARE cursor1 CURSOR
    FOR
    SELECT  MOId, IsExpand, MOPackQty
    FROM    @TempMO;
    OPEN cursor1;
    FETCH NEXT FROM cursor1 
	INTO @MOId, @IsExpand, @MOPackQty;
    WHILE @@FETCH_STATUS = 0
    BEGIN		

        SET @MOProductId = '';		
        SET @BOMId = '';
        SET @MOProductName = '';
        SET @ItemQtyRequired = 0;
        SET @IsBom = 0;

        SELECT  @MOProductId = ProductId
        FROM    MO
        WHERE   MOId = @MOId;

        SELECT  @MOProductName = ProductRoot.ProductName
        FROM    Product
        INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
        WHERE   Product.ProductId = @MOProductId;
		
        SELECT  @KDMOId = KDMOId
        FROM    KDMO
        WHERE   KDOrderInfoId = @KDOrderInfoId AND MOId = @MOId;

        SELECT  @BOMId = BOMId
        FROM    BOMRoot
        INNER JOIN BOM ON BOM.BOMRootId = BOMRoot.BOMRootId
        WHERE   BOMName = @MOProductName; 

        IF @IsExpand = 1
        BEGIN
            DECLARE cursor2 CURSOR
            FOR
            SELECT  MOItemId, ProductId, BOMQtyRequired, ItemQtyRequired
            FROM    MOItem
            WHERE   MOId = @MOId AND LineSequence <> '0000' AND ItemQtyRequired > 0 
			        AND (DeleteFlag <> 'X' ); --这个地方注意会影响物料生成的数目
            OPEN cursor2;
            FETCH NEXT FROM cursor2
			INTO @MOItemId, @MProductId, @BOMQtyRequired, @MOItemQtyRequired;
            WHILE @@FETCH_STATUS = 0
            BEGIN

                SET @UOMId = '';
                SET @ModuleName = '';
                SET @MProductName = '';
                SET @CustomerNumber = '';
                SET @EnglishDescription = '';
                SET @FieldsA = '';	
                SET @FieldsB = '';
                SET @SingleWeight = 0;  
                SET @IsIgnore = 0;

				--获取BOM组件信息
                SELECT  @ModuleName = ModuleName, @CustomerNumber = CustomerNumber,
                        @EnglishDescription = EnglishDescription, @FieldsA = FieldsA, @FieldsB = FieldsB,
                        @SingleWeight = SingleWeight, @IsIgnore = IsIgnore, @QtyPack = QtyPack
                FROM    BOMItem
                WHERE   BOMItem.BOMId = @BOMId AND BOMItem.ProductId = @MProductId;
				
                SELECT  @MSOName = b.SOName
                FROM    MOItem a WITH ( NOLOCK )
                INNER JOIN MO b WITH ( NOLOCK ) ON a.MOId = b.MOId
                WHERE   a.MOItemId = @MOItemId;

                SELECT  @UOMId = UsageUOMId, @MProductName = [dbo].[RemoveZero](ProductRoot.ProductName)
                FROM    Product
                INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
                WHERE   ProductId = @MProductId;

                IF ISNULL(@ModuleName, '') = ''
                BEGIN
                    SET @ModuleName = @MProductName;
                    SET @IsBom = 0;
                END;
                ELSE
                BEGIN
                    SET @IsBom = 1;
                END;
				

                IF @QtyPack = 0
                    SET @QtyPack = @BOMQtyRequired;

                SET @ItemQtyRequired = @QtyPack * @MOPackQty;
				
				

                IF NOT EXISTS ( SELECT  1
                                FROM    KDOrderItem
                                WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @MProductId )
                BEGIN

					--写入
                    EXEC SysGetObjectPKId
                        '' ,
                        'KDOrderItem' ,
                        @KDOrderItemId OUTPUT;
                    INSERT  INTO KDOrderItem ( KDOrderItemId, KDOrderInfoId, ProductId, ModuleName, CustomerNumber,
                                               EnglishDescription, FieldsA, FieldsB, SingleWeight, BOMQtyRequired,
                                               ItemQtyRequired, QtyPack, UOMId, IsIgnore, CreateUserId )
                    VALUES  ( @KDOrderItemId, @KDOrderInfoId, @MProductId, [dbo].[RemoveZero](@ModuleName),
                              [dbo].[RemoveZero](@CustomerNumber), @EnglishDescription, @FieldsA, @FieldsB,
                              @SingleWeight, @BOMQtyRequired, @ItemQtyRequired, @QtyPack, @UOMId, @IsIgnore,
                              @I_OrBitUserId );

							--IF @I_OrBitUserName='2061399'
							--RETURN 0;
                END;
                ELSE
                BEGIN
                    SELECT  @KDOrderItemId = KDOrderItemId
                    FROM    KDOrderItem
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @MProductId;
					--如果是BOM里面存在的品号,更新订单组件信息,如果是工单里面的品号只更新需求数量,包装数量和单位
					---手动新增物料不改变,改变bom表的物料---
                    IF @IsBom = 1
                    BEGIN
                        UPDATE  KDOrderItem
                        SET     ModuleName = [dbo].[RemoveZero](@ModuleName),
                                CustomerNumber = [dbo].[RemoveZero](@CustomerNumber),
                                EnglishDescription = @EnglishDescription, FieldsA = @FieldsA, FieldsB = @FieldsB,
                                SingleWeight = @SingleWeight, BOMQtyRequired = @BOMQtyRequired,
                                ItemQtyRequired = ItemQtyRequired + @ItemQtyRequired, QtyPack = @QtyPack, UOMId = @UOMId,
                                IsIgnore = @IsIgnore
                        WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @MProductId AND IsAdd = 0;
                    END;
                    ELSE
                        UPDATE  KDOrderItem
                        SET     ItemQtyRequired = ItemQtyRequired + @ItemQtyRequired, QtyPack = @QtyPack, UOMId = @UOMId
                        WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @MProductId AND IsAdd = 0;
                END;
				
                IF @I_PlugInCommand = 'KDYN'
                BEGIN
                    IF NOT EXISTS ( SELECT  1
                                    FROM    KDMOItem a
                                    INNER JOIN KDOrderItem b ON a.KDOrderItemId = b.KDOrderItemId
                                    WHERE   b.KDOrderItemId = @KDOrderItemId AND a.MOItemId = @MOItemId )
                    BEGIN	
						--写入
                        EXEC SysGetObjectPKId
                            '' ,
                            'KDMOItem' ,
                            @KDMOItemId OUTPUT;
                        INSERT  INTO KDMOItem ( KDMOItemId, KDOrderItemId, MOItemId, ProductId, ItemQtyRequired, SOName )
                        VALUES  ( @KDMOItemId, @KDOrderItemId, @MOItemId, @MProductId, @MOItemQtyRequired, @MSOName );
                    END;
                END;

                FETCH NEXT FROM cursor2
				INTO @MOItemId, @MProductId, @BOMQtyRequired, @MOItemQtyRequired;
            END;
            CLOSE cursor2;
            DEALLOCATE cursor2;
        END;

        IF @IsExpand = 0
        BEGIN
            DECLARE cursor3 CURSOR
            FOR
            SELECT  ProductId, BOMQtyRequired
            FROM    MOItem
            WHERE   MOId = @MOId AND LineSequence = '0000';
            OPEN cursor3;
            FETCH NEXT FROM cursor3
			INTO @MProductId, @BOMQtyRequired;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @UOMId = '';
                SET @ModuleName = '';
                SET @MProductName = '';
                SET @CustomerNumber = '';
                SET @EnglishDescription = '';
                SET @FieldsA = '';	
                SET @FieldsB = '';
                SET @SingleWeight = 0;  
                SET @IsIgnore = 0;

				--获取BOM组件信息
                SELECT  @ModuleName = ModuleName, @CustomerNumber = CustomerNumber,
                        @EnglishDescription = EnglishDescription, @FieldsA = FieldsA, @FieldsB = FieldsB,
                        @SingleWeight = SingleWeight, @IsIgnore = IsIgnore, @QtyPack = QtyPack
                FROM    BOMItem
                WHERE   BOMItem.BOMId = @BOMId AND BOMItem.ProductId = @MProductId;

                IF ISNULL(@ModuleName, '') = ''
                    SET @ModuleName = @MProductName;

				--add by wangrt 2025-03-17
				IF ISNULL(@EnglishDescription,'') = ''
				BEGIN
					SELECT @EnglishDescription = EngDesc
					FROM dbo.Product
					WHERE ProductId = @MProductId
				END

                IF @QtyPack = 0
                    SET @QtyPack = @BOMQtyRequired;

                SELECT  @UOMId = UsageUOMId, @MProductName = [dbo].[RemoveZero](ProductRoot.ProductName)
                FROM    Product
                INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
                WHERE   ProductId = @MProductId;

                IF ISNULL(@ModuleName, '') = ''
                    SET @ModuleName = @MProductName;

                SET @ItemQtyRequired = @QtyPack * @MOPackQty;

                IF NOT EXISTS ( SELECT  1
                                FROM    KDOrderItem
                                WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @MProductId )
                BEGIN
					--写入
                    EXEC SysGetObjectPKId
                        '' ,
                        'KDOrderItem' ,
                        @KDOrderItemId OUTPUT;
                    INSERT  INTO KDOrderItem ( KDOrderItemId, KDOrderInfoId, ProductId, CustomerNumber, ModuleName,
                                               EnglishDescription, FieldsA, FieldsB, SingleWeight, BOMQtyRequired,
                                               ItemQtyRequired, QtyPack, UOMId, IsIgnore, CreateUserId )
                    VALUES  ( @KDOrderItemId, @KDOrderInfoId, @MProductId, [dbo].[RemoveZero](@CustomerNumber),
                              [dbo].[RemoveZero](@ModuleName), @EnglishDescription, @FieldsA, @FieldsB, @SingleWeight,
                              @BOMQtyRequired, @ItemQtyRequired, @QtyPack, @UOMId, @IsIgnore, @I_OrBitUserId );
                END;
                ELSE
                BEGIN
                    SET @KDOrderItemId = '';

                    SELECT TOP 1
                            @KDOrderItemId = KDOrderItemId
                    FROM    KDOrderItem
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @MProductId;

					--更新订单组件信息
                    UPDATE  KDOrderItem
                    SET     ModuleName = [dbo].[RemoveZero](@ModuleName),
                            CustomerNumber = [dbo].[RemoveZero](@CustomerNumber),
                            EnglishDescription = @EnglishDescription, FieldsA = @FieldsA, FieldsB = @FieldsB,
                            SingleWeight = @SingleWeight, BOMQtyRequired = @BOMQtyRequired,
                            ItemQtyRequired = ItemQtyRequired + @ItemQtyRequired, QtyPack = @QtyPack, UOMId = @UOMId,
                            IsIgnore = @IsIgnore
                    WHERE   KDOrderItemId = @KDOrderItemId;
                END;

                FETCH NEXT FROM cursor3
				INTO @MProductId, @BOMQtyRequired;
            END;
            CLOSE cursor3;
            DEALLOCATE cursor3;
        END;

        FETCH NEXT FROM cursor1 
		INTO @MOId, @IsExpand, @MOPackQty;
    END;
    CLOSE cursor1;
    DEALLOCATE cursor1; 


		UPDATE b SET b.IsExpand = 1
	FROM @TempMO a INNER JOIN dbo.KDMO b ON b.MOId = a.MOId
    

    SET @I_ReturnMessage = 'ServerMessage:工单明细同步成功!';

    RETURN 0;
END;

