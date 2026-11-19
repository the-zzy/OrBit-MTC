CREATE PROCEDURE [dbo].[SP_SyncMOItemToKDOrderDoMethod]
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
    
    BEGIN TRY
        -- 声明变量
        DECLARE @MOId CHAR(12);
        DECLARE @KDOrderItemId CHAR(12);
        DECLARE @KDMOItemId CHAR(12);
        DECLARE @MOItemId CHAR(12);
        DECLARE @ProductId CHAR(12);
        DECLARE @ItemQtyRequired DECIMAL(18, 4);
        DECLARE @MOPackQty DECIMAL(18, 2);
        DECLARE @UOMId CHAR(12);
        DECLARE @SOName NVARCHAR(50);
        DECLARE @KDOrderInfoId CHAR(12);
        DECLARE @kdordername NVARCHAR(20);

        DECLARE @ProductName NVARCHAR(50) = '';

        -- 创建临时表存储需要同步的数据
        CREATE TABLE #TempNewItems
            (
              MOItemId CHAR(12) ,
              ProductId CHAR(12) ,
              ItemQtyRequired DECIMAL(18, 4) ,
              MOId CHAR(12) ,
              SOName NVARCHAR(50)
            );
        
			--获取散件订单信息
        SELECT  @KDOrderInfoId = KDOrderInfoId, @kdordername = OrderName
        FROM    KDOrderInfo
        WHERE   KDOrderInfoId = @I_ParentPKId;

        IF CAST(RIGHT(@kdordername, 1) AS INT) > 1 AND @kdordername <> 'JB2025052710-3'
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 非第一批订单，禁止操作';
            RETURN -1;
        END;

        -- 获取需要同步的新物料
        INSERT  INTO #TempNewItems
                SELECT DISTINCT
                        mi.MOItemId, mi.ProductId, mi.ItemQtyRequired, mi.MOId, mo.SOName
                FROM    MOItem mi
                INNER JOIN MO mo ON mi.MOId = mo.MOId
                INNER JOIN KDMO km ON km.MOId = mo.MOId
                LEFT JOIN KDOrderItem ki ON ki.KDOrderInfoId = @KDOrderInfoId AND ki.ProductId = mi.ProductId
                WHERE   km.KDOrderInfoId = @KDOrderInfoId AND ki.KDOrderItemId IS NULL AND mi.DeleteFlag <> 'X' AND mi.ItemQtyRequired > 0;

        DELETE  a
        FROM    #TempNewItems a
        INNER JOIN Product b ON b.ProductId = a.ProductId
        WHERE   b.prdname LIKE '515%';
        
		     SELECT  ProductId, SUM(ItemQtyRequired), MOId, SOName,MOItemId
        FROM    #TempNewItems
        GROUP BY ProductId, MOId, SOName,MOItemId


        -- 处理每一条新物料记录
        DECLARE cur_NewItems CURSOR
        FOR
        SELECT  ProductId, SUM(ItemQtyRequired), MOId, SOName,MOItemId
        FROM    #TempNewItems
        GROUP BY ProductId, MOId, SOName,MOItemId
        
        OPEN cur_NewItems;
        FETCH NEXT FROM cur_NewItems INTO @ProductId, @ItemQtyRequired, @MOId, @SOName,@MOItemId
            
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- 获取包装数量
            SELECT  @MOPackQty = MOPackQty
            FROM    KDMO
            WHERE   MOId = @MOId;
            
            -- 获取单位
            SELECT  @UOMId = UsageUOMId, @ProductName = prdname
            FROM    Product
            WHERE   ProductId = @ProductId;
            
            IF NOT EXISTS ( SELECT  1
                            FROM    dbo.KDOrderItem
                            WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @ProductId  )
            BEGIN
				-- 插入KDOrderItem
                EXEC SysGetObjectPKId
                    '' ,
                    'KDOrderItem' ,
                    @KDOrderItemId OUTPUT;
            
                INSERT  INTO KDOrderItem ( KDOrderItemId, KDOrderInfoId, ProductId, ModuleName, CustomerNumber,
                                           ItemQtyRequired, QtyPack, UOMId, IsAdd, CreateUserId, CreateDate )
                VALUES  ( @KDOrderItemId, @KDOrderInfoId, @ProductId, @ProductName, @ProductName, @ItemQtyRequired, 1,
                          @UOMId, 1, @I_OrBitUserId, GETDATE() );

				--IF NOT EXISTS(SELECT 1 FROM dbo.KDMOItem WHERE KDOrderItemId=@KDOrderItemId)
				--BEGIN
					            
				--		-- 插入KDMOItem
				--		EXEC SysGetObjectPKId
				--			'' ,
				--			'KDMOItem' ,
				--			@KDMOItemId OUTPUT;
            
				--		INSERT  INTO KDMOItem ( KDMOItemId, KDOrderItemId, MOItemId, ProductId, ItemQtyRequired, SOName )
				--		VALUES  ( @KDMOItemId, @KDOrderItemId, @MOItemId, @ProductId, @ItemQtyRequired, @SOName);

				--END
                

            END;
            ELSE
            BEGIN
                SELECT  @KDOrderItemId = KDOrderItemId
                FROM    dbo.KDOrderItem
                WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @ProductId;

                UPDATE  dbo.KDOrderItem
                SET     ItemQtyRequired = ISNULL(ItemQtyRequired, 0) + ISNULL(@ItemQtyRequired, 0)
                WHERE   KDOrderItemId = @KDOrderItemId;
            END;
            
            ---- 插入KDMOItem
            EXEC SysGetObjectPKId '', 'KDMOItem', @KDMOItemId OUTPUT
            
            INSERT INTO KDMOItem
            (
                KDMOItemId, KDOrderItemId, MOItemId,
                ProductId, ItemQtyRequired, SOName
            )
            VALUES
            (
                @KDMOItemId, @KDOrderItemId, @MOItemId,
                @ProductId, @ItemQtyRequired, @SOName
            )
            
            FETCH NEXT FROM cur_NewItems INTO @ProductId, @ItemQtyRequired, @MOId, @SOName,@MOItemId
        END;
        
        CLOSE cur_NewItems;
        DEALLOCATE cur_NewItems;


		      --  -- 处理每一条新物料记录

        -- 清理临时表
        DROP TABLE #TempNewItems;
        
        SET @I_ReturnMessage = 'ServerMessage:新增物料同步成功！';
        RETURN 0;
    END TRY
    BEGIN CATCH
        SET @I_ReturnMessage = 'ServerMessage:同步失败！' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH;
END;

