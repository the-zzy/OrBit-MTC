--**==================================================------
--****************************************************------
--**注意:元对象 Old存储过程将被覆盖，存储过程更新包括 ViewList过程的更新
--****************************************************------
--**==================================================------
-- =============================================
-- Author:            <1003153>
-- Create date:       <2026.11.05>
-- Description:       CKD 装箱(越南)。V2 版本改造点：
--                    1、扫描条码在基板MES库存中不存在时，自动触发“总装MES库存转基板MES库存”，
--                       转换过程由 SYNC_WWRMInventoryFromTV 改为 SYNC_WWRMInventoryFromZZ
--                       （老过程引用了总装表已删除的列 IsIQCHold/PalletSN，现已无法执行）。
--                    2、转换失败时，把转换过程的真实原因透传给PDA，不再统一吞成“扫描批号无效”。
--                    3、补外层 TRY/CATCH，异常写 SqlProcedureIssueLog，并释放 locktable 业务锁。
--                    除以上三点外，装箱主流程（组件校验、ShipBox、KDMOItem 分配、净重、发料数量回写）
--                    与原版完全一致。
-- =============================================
-- V3 (2026-11-16) 合盘批号放行（2026-11-16-ckd-packing-merge-lot）：
--     SMT 料盘合盘（Txn_SMTReelMerge）生成的新批号只写 WW_RMInventory，
--     不在发货单批号清单（MaterialIssuanceItemLot / StockListItemLot）上，
--     CKD 装箱扫合盘批号报「扫描批号非仓库发货单批号」。
--     改法：在原 MTL% 校验内追加两个放行条件（原校验语义不变，只是多一条逃生通道）——
--       ① 所有不在发货单上的扫描批号，都必须是有效合盘批号（SMTReelMerge.IsCancel=0）；
--       ② 每个合盘批号的全部子盘（SMTReelMergeItem.IsCancel=0）都必须在本发货单上。
--     两条同时满足才放行；任一不满足仍报原错误。
--     已知限制：合盘的合盘（嵌套合盘，子盘本身又是合盘批号）不放行，仍报错，属预期拦截。
-- =============================================
ALTER PROCEDURE [dbo].[PDA_CKDPacking_YN]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,			--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKid CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(MAX) = '' ,  		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @Operator NVARCHAR(10) = '' , -- 工号
    @BoxSN VARCHAR(50) = '' , 		-- 箱号
    @ScanSN VARCHAR(50) = ''          --最小包/外箱 SN
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        DECLARE @MOId CHAR(12);
        DECLARE @ProductId CHAR(12);
        DECLARE @ProductName VARCHAR(50);
        DECLARE @LotQty DECIMAL(18, 4);
        DECLARE @LotSN VARCHAR(50);
        DECLARE @MOItemId CHAR(12);
        DECLARE @SOName NVARCHAR(50);
        DECLARE @KDOrderItemId CHAR(12);
        DECLARE @KDMOItemLotId CHAR(12);
        DECLARE @KDMOId CHAR(12);
        DECLARE @KDMOItemId CHAR(12);
        DECLARE @lockFlag VARCHAR(50);
        DECLARE @TotalNetWeight DECIMAL(18, 4);   --净重 KG

        DECLARE @AllQty DECIMAL(18, 4);  --需求剩余数量
        DECLARE @MLotQty DECIMAL(18, 4);  --批号剩余数量

        DECLARE @OrderName VARCHAR(20);
        DECLARE @TempPKId TABLE ( Seq INT, PKId CHAR(12) );
        DECLARE @Count INT;
        DECLARE @ScanQty DECIMAL(18, 4);  --本箱已装箱数量
        DECLARE @RealQty DECIMAL(18, 4);  --本箱本物料已装箱数量

        DECLARE @KDOrderInfoId CHAR(12);
        DECLARE @MaterialIssuanceId CHAR(12); -- 发料单ID
        DECLARE @KDBoxInfoId CHAR(12);
        DECLARE @KDBoxItemId CHAR(12);
        DECLARE @OriginalBoxSN NVARCHAR(50);

        DECLARE @LotSNList TABLE
            (
              Seq INT IDENTITY ,
              LotSN VARCHAR(50) ,
              ProductId CHAR(12) ,
              LotQty DECIMAL(18, 4) ,
              IsSplit BIT
            );

        --检查工号是否存在
        IF NOT EXISTS ( SELECT  1
                        FROM    PersonInfo
                        WHERE   PersonNumber = @Operator AND IsActivity = 1 )
        BEGIN
            SELECT  '' AS ScanSN;
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}操作员工号 [' + @Operator + '] 无效，请检查!';
            SET @I_ExceptionFieldName = 'Operator';
            RETURN -1;
        END;

        IF EXISTS ( SELECT  1
                    FROM    dbo.KDBoxInfo
                    WHERE   BoxSN = @ScanSN AND IsCancel = 0 )
        BEGIN
            SELECT  @OrderName = a.OrderName, @BoxSN = b.BoxSN
            FROM    KDOrderInfo a
            INNER JOIN KDBoxInfo b ON a.KDOrderInfoId = b.KDOrderInfoId
            WHERE   b.BoxSN = @ScanSN AND b.IsCancel = 0;

            SELECT  '' AS ScanSN, @OrderName AS OrderName, @BoxSN AS BoxSN;

            SET @I_ReturnMessage = 'ServerMessage: 获取箱号成功!';
            RETURN 0;
        END;

        --检查箱号是否为空
        IF ISNULL(@BoxSN, '') = ''
        BEGIN
            SELECT  '' AS ScanSN;
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请先扫描箱号!';
            SET @I_ExceptionFieldName = 'ScanSN';
            RETURN -1;
        END;

        --获取订单数据
        SELECT  @OrderName = a.OrderName
        FROM    KDOrderInfo a
        INNER JOIN KDBoxInfo b ON a.KDOrderInfoId = b.KDOrderInfoId
        WHERE   b.BoxSN = @BoxSN AND b.IsCancel = 0;

        IF LEFT(@ScanSN, 1) = 'R'
        BEGIN
            INSERT  INTO @LotSNList ( LotSN, ProductId, LotQty, IsSplit )
                    SELECT  LotSN, ProductId, LotQty, IIF(LotQty < ISNULL(OriginalQty, 0), 1, 0)
                    FROM    dbo.WW_RMInventory
                    WHERE   LotSN = @ScanSN AND IsCancel = 0;

            SELECT  @OriginalBoxSN = BoxSN
            FROM    dbo.WW_RMInventory
            WHERE   LotSN = @ScanSN AND IsCancel = 0;
        END;

        IF LEFT(@ScanSN, 1) = 'B'
        BEGIN
            INSERT  INTO @LotSNList ( LotSN, ProductId, LotQty, IsSplit )
                    SELECT  a.LotSN, a.ProductId, a.LotQty, IIF(a.LotQty < ISNULL(a.OriginalQty, 0), 1, 0)
                    FROM    dbo.WW_RMInventory a WITH(NOLOCK)
                    LEFT JOIN dbo.VendorDeliveryItemLot  b WITH(NOLOCK) ON b.LotSN = a.LotSN
                    WHERE   b.BoxSN = @ScanSN AND a.IsCancel = 0;

            SET @OriginalBoxSN = @ScanSN;
        END;

        ------------------------------------------------------------------
        -- V2：条码在基板MES库存中不存在 → 触发“总装MES库存转基板MES库存”
        ------------------------------------------------------------------
        DECLARE @syncFlag BIT = 0;
        DECLARE @SyncRet INT = 0;                 --转换过程返回值 0成功 -1失败
        DECLARE @SyncMsg NVARCHAR(MAX) = '';      --转换过程返回信息

        IF NOT EXISTS ( SELECT  1 FROM @LotSNList )
        BEGIN
            SET @syncFlag = 1;

            EXEC @SyncRet = dbo.SYNC_WWRMInventoryFromZZ
                @LotSN = @ScanSN,
                @I_ReturnMessage = @SyncMsg OUTPUT;

            --转换后重新取库存（R=小包条码按LotSN取，B=箱条码按BoxSN取）
            IF LEFT(@ScanSN, 1) = 'R'
            BEGIN
                INSERT  INTO @LotSNList ( LotSN, ProductId, LotQty, IsSplit )
                        SELECT  LotSN, ProductId, LotQty, IIF(LotQty < ISNULL(OriginalQty, 0), 1, 0)
                        FROM    dbo.WW_RMInventory
                        WHERE   LotSN = @ScanSN AND IsCancel = 0;

                SELECT  @OriginalBoxSN = BoxSN
                FROM    dbo.WW_RMInventory
                WHERE   LotSN = @ScanSN AND IsCancel = 0;
            END;

            IF LEFT(@ScanSN, 1) = 'B'
            BEGIN
                INSERT  INTO @LotSNList ( LotSN, ProductId, LotQty, IsSplit )
                        SELECT  LotSN, ProductId, LotQty, IIF(LotQty < ISNULL(OriginalQty, 0), 1, 0)
                        FROM    dbo.WW_RMInventory
                        WHERE   BoxSN = @ScanSN AND IsCancel = 0;

                SET @OriginalBoxSN = @ScanSN;
            END;
        END;

        IF NOT EXISTS ( SELECT  1 FROM @LotSNList )
        BEGIN
            SELECT  '' AS ScanSN;

            IF @syncFlag = 1 AND @SyncRet <> 0
                --转换失败：透传转换过程的真实原因，便于现场判断（不在总装库存/物料未维护/条码规则不符等）
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}条码[' + @ScanSN
                                     + ']在基板MES库存中不存在，总装库存转换失败：'
                                     + REPLACE(ISNULL(@SyncMsg, ''), 'ServerMessage:', '');
            ELSE IF @syncFlag = 1
                --转换返回成功但仍无有效库存：通常只有已取消记录，或转换后数量为0
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}条码[' + @ScanSN
                                     + ']转换后仍未取得有效库存(可能仅有已取消记录)，请检查!';
            ELSE
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}扫描批号无效,请检查!' + @ScanSN;

            SET @I_ExceptionFieldName = 'ScanSN';
            RETURN -1;
        END;

        SELECT  @Count = COUNT(1)
        FROM    @LotSNList;

        SELECT  @ProductId = ProductId
        FROM    @LotSNList;

        SELECT  @ProductName = prdname
        FROM    Product
        WHERE   ProductId = @ProductId;

        SELECT  @KDBoxInfoId = KDBoxInfoId, @KDOrderInfoId = KDOrderInfoId
        FROM    dbo.KDBoxInfo
        WHERE   BoxSN = @BoxSN AND IsCancel = 0;

        SELECT @MaterialIssuanceId =CreateUserId FROM	dbo.KDOrderInfo   WHERE KDOrderInfoId = @KDOrderInfoId

        IF NOT EXISTS(SELECT 1 FROM dbo.MaterialIssuanceItem a (NOLOCK)
                        INNER JOIN dbo.MaterialIssuanceItemLot b (NOLOCK) ON b.MaterialIssuanceItemID = a.MaterialIssuanceItemID
                        INNER JOIN @LotSNList c ON c.LotSN = b.LotSN
                        WHERE a.MaterialIssuanceID=@MaterialIssuanceId ) AND  @MaterialIssuanceId LIKE 'MTL%'
        BEGIN

           IF NOT EXISTS(SELECT 1 FROM   dbo.StockListItemLot (NOLOCK) a
                         INNER JOIN @LotSNList b ON b.LotSN = a.LotSN )
             	             --V3 合盘放行：扫的是合盘新批号时，改看它的子盘是否都在本发货单上
	             --   命中任一情形即报原错误：① 有既不在发货单、也不是有效合盘批号的盘；
	             --                             ② 有合盘批号的子盘不在本发货单上
	             AND ( EXISTS ( SELECT 1
	                           FROM   @LotSNList s
	                           WHERE  NOT EXISTS ( SELECT 1
	                                               FROM   dbo.MaterialIssuanceItem a (NOLOCK)
	                                               INNER JOIN dbo.MaterialIssuanceItemLot b (NOLOCK) ON b.MaterialIssuanceItemID = a.MaterialIssuanceItemID
	                                               WHERE  a.MaterialIssuanceID = @MaterialIssuanceId AND b.LotSN = s.LotSN )
	                             AND  NOT EXISTS ( SELECT 1
	                                               FROM   dbo.SMTReelMerge m (NOLOCK)
	                                               WHERE  m.MergeSN = s.LotSN AND m.IsCancel = 0 ) )
	                OR  EXISTS ( SELECT 1
	                           FROM   dbo.SMTReelMerge m (NOLOCK)
	                           INNER JOIN dbo.SMTReelMergeItem i (NOLOCK) ON i.SMTReelMergeId = m.SMTReelMergeId AND i.IsCancel = 0
	                           WHERE  m.MergeSN IN ( SELECT LotSN FROM @LotSNList ) AND m.IsCancel = 0
	                             AND  NOT EXISTS ( SELECT 1
	                                               FROM   dbo.MaterialIssuanceItem a (NOLOCK)
	                                               INNER JOIN dbo.MaterialIssuanceItemLot b (NOLOCK) ON b.MaterialIssuanceItemID = a.MaterialIssuanceItemID
	                                               WHERE  a.MaterialIssuanceID = @MaterialIssuanceId AND b.LotSN = i.LotSN ) ) )
           BEGIN

                  SELECT  '' AS ScanSN;
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}扫描批号非仓库发货单批号!' + @ScanSN;
                SET @I_ExceptionFieldName = 'ScanSN';
                RETURN -1;

            END

        END

        SELECT  @KDOrderItemId = KDOrderItemId
        FROM    KDOrderItem
        WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @ProductId;

        PRINT @ProductName
        PRINT @KDOrderInfoId;
        PRINT @KDBoxInfoId;
        PRINT @ProductId;
        PRINT @KDOrderItemId;
        IF ISNULL(@KDOrderInfoId, '') = '' OR ISNULL(@KDBoxInfoId, '') = '' OR ISNULL(@ProductId, '') = '' OR ISNULL(@KDOrderItemId,
                                                                                                            '') = ''
        BEGIN
            SELECT  '' AS ScanSN;
            SET @I_ReturnMessage = 'ServerMessage:装箱数据错误，请联系IT!' + @BoxSN;
            SET @I_ExceptionFieldName = 'ScanSN';
            RETURN -1;
        END;

        IF @ProductName<>'60101018091'
         BEGIN

        IF EXISTS (
            SELECT 1
            FROM @LotSNList a
            LEFT JOIN dbo.MaterialIssuanceItemLot c ON c.LotSN = a.LotSN
            --LEFT JOIN dbo.WW_RMInventory b ON a.LotSN = b.LotSN
            WHERE  c.LotSN =''
        )
        BEGIN
            SELECT  '' AS ScanSN;
            SET @I_ReturnMessage = 'ServerMessage:仓库未发料,请检查!' + @Scansn;
            SET @I_ExceptionFieldName = 'ScanSN';
            RETURN -1;
        END

        END

        SET @lockFlag = @KDOrderInfoId + '/' + @ProductId;

        BEGIN TRY
            INSERT  INTO dbo.locktable ( lockflag, locktime )
            VALUES  ( @lockFlag, GETDATE() );
        END TRY
        BEGIN CATCH
            DELETE  FROM dbo.locktable
            WHERE   lockflag = @lockFlag;

            SET @I_ReturnMessage = 'ServerMessage:此操作正在执行中,ID::' + @lockFlag + '，已被锁定,请重试!';
            RETURN -1;
        END CATCH;

        IF NOT EXISTS ( SELECT  1
                        FROM    KDMOItem
                        WHERE   KDOrderItemId = @KDOrderItemId AND ProductId = @ProductId )
        BEGIN
            DELETE  FROM dbo.locktable
            WHERE   lockflag = @lockFlag;

            SELECT  '' AS ScanSN;
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}订单中不存在此组件，请检查!' + @ProductId;
            SET @I_ExceptionFieldName = 'ScanSN';
            RETURN -1;
        END;

        INSERT  INTO @TempPKId ( Seq, PKId )
                EXEC dbo.SysGetBatchObjectPKId
                    @ObjectId = '' ,
                    @ObjectName = N'ShipBox' ,
                    @RowCount = @Count;

        IF EXISTS ( SELECT  1
                    FROM    ShipBox a WITH ( NOLOCK )
                    INNER JOIN @LotSNList b ON a.LotSN = b.LotSN
                    WHERE   a.IsCancel = 0 )
        BEGIN
            DELETE  FROM dbo.locktable
            WHERE   lockflag = @lockFlag;

            SELECT  '' AS ScanSN;
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}该批号已装箱!';
            SET @I_ExceptionFieldName = 'ScanSN';
            RETURN -1;
        END;

         IF EXISTS ( SELECT  1
                    FROM   @LotSNList WHERE LotQty =0)
        BEGIN
            DELETE  FROM dbo.locktable
            WHERE   lockflag = @lockFlag;

            SELECT  '' AS ScanSN;
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}该批号数量为0，不可装箱!';
            SET @I_ExceptionFieldName = 'ScanSN';
            RETURN -1;
        END;

        --拿不到 KDMOItemId  得拦截提示

        IF  NOT EXISTS(SELECT 1 FROM  @LotSNList  a INNER JOIN dbo.KDMOItem b ON b.ProductId = a.ProductId
                        WHERE b.KDOrderItemId=@KDOrderItemId AND ItemQtyRequired > IssuedQty)
        BEGIN

            -- 要去重新同步生成 kdmoitem 的数据

            IF EXISTS(SELECT 1 FROM dbo.kdmo a (NOLOCK)
                      INNER JOIN dbo.MOItem b ON b.MOId = a.MOId AND b.ProductId= @ProductId AND b.DeleteFlag<>'x' AND b.ItemQtyRequired > 0
                      LEFT JOIN dbo.KDMOItem c ON b.MOItemId= c.MOItemId
                      WHERE a.KDOrderInfoId= @KDOrderInfoId AND c.MOItemId IS NULL )
            BEGIN

                EXEC [dbo].[KDOrderExpandItemDoMethod_ForSingleMaterial] @I_Sender = N'',                                      -- nvarchar(200)
                                                                        @I_ReturnMessage = @I_ReturnMessage OUTPUT,           -- nvarchar(max)
                                                                        @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT, -- nvarchar(100)
                                                                        @I_LanguageId = '',                                   -- char(1)
                                                                        @I_PlugInCommand = 'KDYN',                                -- varchar(5)
                                                                        @I_OrBitUserId = '',                                  -- char(12)
                                                                        @I_OrBitUserName = N'',                               -- nvarchar(100)
                                                                        @I_ResourceId = '',                                   -- char(12)
                                                                        @I_ResourceName = N'',                                -- nvarchar(100)
                                                                        @I_PKid = @KDOrderInfoId,                                         -- char(12)
                                                                        @I_ParentPKId = @KDOrderInfoId,                                   -- char(12)
                                                                        @I_Parameter = N'',                                   -- nvarchar(100)
                                                                        @productid = @ProductId                                       -- char(12)

            END

            IF EXISTS(SELECT 1 FROM dbo.kdmo a (NOLOCK)
                INNER JOIN dbo.MOItem b ON b.MOId = a.MOId AND b.ProductId= @ProductId AND b.DeleteFlag<>'x' AND b.ItemQtyRequired > 0
                LEFT JOIN dbo.KDMOItem c ON b.MOItemId= c.MOItemId
                WHERE a.KDOrderInfoId= @KDOrderInfoId AND c.MOItemId IS NULL )
            BEGIN

                DELETE  FROM dbo.locktable
                WHERE   lockflag = @lockFlag;

                SELECT  '' AS ScanSN;
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}此物料未全部展开，不可装箱![PDA_CKDPacking_YN]'+@KDOrderItemId;
                SET @I_ExceptionFieldName = 'ScanSN';
                RETURN -1;

            END

            IF EXISTS(SELECT 1 FROM dbo.kdmo a (NOLOCK)
                      INNER JOIN dbo.MOItem b ON b.MOId = a.MOId AND b.ProductId= @ProductId AND b.DeleteFlag<>'x' AND b.ItemQtyRequired > 0
                      INNER JOIN dbo.KDMOItem c ON b.MOItemId= c.MOItemId
                      WHERE a.KDOrderInfoId= @KDOrderInfoId AND c.ItemQtyRequired <> b.ItemQtyRequired )
            BEGIN

                DELETE  FROM dbo.locktable
                WHERE   lockflag = @lockFlag;

                SELECT  '' AS ScanSN;
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}此物料数量已变更，不可装箱![PDA_CKDPacking_YN]'+@KDOrderItemId;
                SET @I_ExceptionFieldName = 'ScanSN';
                RETURN -1;

            END
        END;

        --更新组件
        IF NOT EXISTS ( SELECT  1
                        FROM    KDBoxItem a
                        INNER JOIN KDBoxInfo b ON a.KDBoxInfoId = b.KDBoxInfoId
                        WHERE   b.KDBoxInfoId = @KDBoxInfoId AND a.ProductId = @ProductId )
        BEGIN
            EXEC SysGetObjectPKId
                '' ,
                'KDBoxItem' ,
                @KDBoxItemId OUTPUT;

            INSERT  INTO dbo.KDBoxItem ( KDBoxItemId, KDOrderInfoId, KDBoxInfoId, ProductId, CreateUserId, KDOrderItemId )
            VALUES  ( @KDBoxItemId, @KDOrderInfoId, @KDBoxInfoId, @ProductId, @I_OrBitUserId, @KDOrderItemId );
        END;
        ELSE
        BEGIN
            --如果组件无效则恢复
            UPDATE  dbo.KDBoxItem
            SET     IsCancel = 0
            WHERE   KDBoxInfoId = @KDBoxInfoId AND ProductId = @ProductId AND IsCancel = 1;
        END;

        --开始装箱
        INSERT  INTO dbo.ShipBox ( ShipBoxId, BoxSN, LotSN, ProductId, UserId, OriginalBoxSN, Qty )
                SELECT  b.PKId, @BoxSN, a.LotSN, a.ProductId, @I_OrBitUserId, @OriginalBoxSN, a.LotQty
                FROM    @LotSNList a
                INNER JOIN @TempPKId b ON a.Seq = b.Seq;

        SELECT  @ScanQty = SUM(b.LotQty)
        FROM    ShipBox a WITH ( NOLOCK )
        INNER JOIN WW_RMInventory b WITH ( NOLOCK ) ON a.LotSN = b.LotSN
        WHERE   a.BoxSN = @BoxSN AND a.IsCancel = 0;

        SELECT  @RealQty = SUM(b.LotQty)
        FROM    ShipBox a WITH ( NOLOCK )
        INNER JOIN WW_RMInventory b WITH ( NOLOCK ) ON a.LotSN = b.LotSN
        WHERE   a.BoxSN = @BoxSN AND b.ProductId = @ProductId AND a.IsCancel = 0;

        --净重计算
        SELECT  @TotalNetWeight = SUM(b.LotQty * ISNULL(c.UnitNetWeight, 0)) / 1000.00
        FROM    ShipBox a WITH ( NOLOCK )
        INNER JOIN WW_RMInventory b WITH ( NOLOCK ) ON a.LotSN = b.LotSN
        LEFT JOIN Vendor_Product c WITH ( NOLOCK ) ON b.VendorId = c.VendorId AND b.ProductId = c.ProductId
        WHERE   a.BoxSN = @BoxSN AND a.IsCancel = 0
        GROUP BY a.BoxSN;

        UPDATE  KDBoxInfo
        SET     NetWeight = CAST(@TotalNetWeight AS DECIMAL(18, 4))
        WHERE   KDBoxInfoId = @KDBoxInfoId;
        UPDATE  KDBoxItem
        SET     RealQty = @RealQty
        WHERE   KDBoxInfoId = @KDBoxInfoId AND ProductId = @ProductId;

        --开始分配
        DECLARE LotCursor CURSOR
        FOR
        SELECT  LotSN, ProductId, LotQty
        FROM    @LotSNList;
        OPEN LotCursor;
        FETCH NEXT FROM LotCursor INTO @LotSN, @ProductId, @LotQty;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            WHILE @LotQty > 0
            BEGIN
                SET @KDMOId = '';
                SET @KDMOItemId = '';
                SET @AllQty = 0;

                SELECT  @KDMOItemId = KDMOItemId, @AllQty = ItemQtyRequired - ISNULL(IssuedQty, 0)
                FROM    KDMOItem
                WHERE   KDOrderItemId = @KDOrderItemId AND ProductId = @ProductId AND ItemQtyRequired > IssuedQty
                ORDER BY KDOrderItemId DESC;

                --可以继续分配
                IF ISNULL(@KDMOItemId, '') <> ''
                BEGIN
                    IF @LotQty <= @AllQty
                    BEGIN
                        EXEC SysGetObjectPKId
                            '' ,
                            'KDMOItemLot' ,
                            @KDMOItemLotId OUTPUT;

                        INSERT  INTO KDMOItemLot ( KDMOItemLotId, KDMOItemId, LotSN, LotQty, ProductId )
                        VALUES  ( @KDMOItemLotId, @KDMOItemId, @LotSN, @LotQty, @ProductId );

                        UPDATE  dbo.KDMOItem
                        SET     IssuedQty = ISNULL(IssuedQty, 0) + @LotQty
                        WHERE   KDMOItemId = @KDMOItemId;

                        SET @LotQty = 0;
                        CONTINUE;
                    END;
                    BEGIN
                        EXEC SysGetObjectPKId
                            '' ,
                            'KDMOItemLot' ,
                            @KDMOItemLotId OUTPUT;

                        INSERT  INTO KDMOItemLot ( KDMOItemLotId, KDMOItemId, LotSN, LotQty, ProductId )
                        VALUES  ( @KDMOItemLotId, @KDMOItemId, @LotSN, @AllQty, @ProductId );

                        UPDATE  dbo.KDMOItem
                        SET     IssuedQty = ISNULL(IssuedQty, 0) + @AllQty
                        WHERE   KDMOItemId = @KDMOItemId;

                        SET @LotQty = @LotQty - @AllQty;
                        CONTINUE;
                    END;
                END;

                --无法继续分配，则寄存
                /*IF NOT EXISTS (
                    SELECT 1 FROM KDMO WHERE KDOrderInfoId = @KDOrderInfoId AND ISNULL(MOId, '') = ''
                )
                BEGIN
                    EXEC SysGetObjectPKId '', 'KDMO', @KDMOId OUTPUT;
                    INSERT INTO dbo.KDMO (KDMOId, KDOrderInfoId, MOId, MOPackQty, IsExpand)
                    VALUES(@KDMOId, @KDOrderInfoId, '', 0, 0)
                END
                ELSE
                BEGIN
                    SELECT @KDMOId = KDMOId FROM KDMO WHERE KDOrderInfoId = @KDOrderInfoId AND ISNULL(MOId, '') = ''
                END*/

                IF NOT EXISTS ( SELECT  1
                                FROM    KDMOItem
                                WHERE   KDOrderItemId = @KDOrderItemId AND ProductId = @ProductId AND ISNULL(MOItemId, '') = '' )
                BEGIN
                    EXEC SysGetObjectPKId
                        '' ,
                        'KDMOItem' ,
                        @KDMOItemId OUTPUT;
                    INSERT  INTO KDMOItem ( KDMOItemId, KDOrderItemId, MOItemId, ProductId, ItemQtyRequired )
                    VALUES  ( @KDMOItemId, @KDOrderItemId, '', @ProductId, @LotQty );
                END;
                ELSE
                BEGIN
                    SELECT  @KDMOItemId = KDMOItemId
                    FROM    KDMOItem
                    WHERE   KDOrderItemId = @KDOrderItemId AND ProductId = @ProductId AND ISNULL(MOItemId, '') = '';

                    UPDATE  KDMOItem
                    SET     ItemQtyRequired = ISNULL(ItemQtyRequired, 0) + @LotQty
                    WHERE   KDMOItemId = @KDMOItemId;
                END;

                EXEC SysGetObjectPKId
                    '' ,
                    'KDMOItemLot' ,
                    @KDMOItemLotId OUTPUT;

                INSERT  INTO KDMOItemLot ( KDMOItemLotId, KDMOItemId, LotSN, LotQty, ProductId )
                VALUES  ( @KDMOItemLotId, @KDMOItemId, @LotSN, @LotQty, @ProductId );

                UPDATE  dbo.KDMOItem
                SET     IssuedQty = ISNULL(IssuedQty, 0) + @LotQty
                WHERE   KDMOItemId = @KDMOItemId;

                SET @LotQty = 0;
                CONTINUE;
            END;

            FETCH NEXT FROM LotCursor INTO @LotSN, @ProductId, @LotQty;
        END;

        CLOSE LotCursor;
        DEALLOCATE LotCursor;

        --更新组件实际数量

        DECLARE @AllPackQty DECIMAL(18, 4);
        SELECT  @MaterialIssuanceID = CreateUserId
        FROM    KDOrderInfo
        WHERE   KDOrderInfoId = @KDOrderInfoId;

        DECLARE @MaterialScanqty TABLE
            (
              MaterialIssuanceID VARCHAR(12) ,
              MaterialIssuanceItemID VARCHAR(12) ,
              Productid VARCHAR(12) ,
              Scanqty DECIMAL(18, 4)
            );

        DECLARE @StockListId CHAR(12)='';

        SELECT  @StockListId = StockListId
        FROM    dbo.MaterialIssuance WITH ( NOLOCK )
        WHERE   MaterialIssuanceID = @MaterialIssuanceID;

        INSERT  INTO @MaterialScanqty ( MaterialIssuanceID, MaterialIssuanceItemID, Productid, Scanqty )
        SELECT  '', '', v.ProductId, SUM(v.Scanqty)
        FROM    (
                  SELECT    x.ProductId, x.LotSN, MAX(x.Scanqty) AS Scanqty
                  FROM      (
                              -- 发料单
                              SELECT    a.ProductId, a.LotSN, SUM(a.Qty + ISNULL(a.Allotqty, 0)) AS Scanqty
                              FROM      dbo.MaterialIssuanceItemLot a WITH ( NOLOCK )
                              INNER JOIN dbo.MaterialIssuanceItem b WITH ( NOLOCK )
                                  ON b.MaterialIssuanceItemID = a.MaterialIssuanceItemID
                              WHERE     b.MaterialIssuanceID = @MaterialIssuanceID
                                        AND ISNULL(a.BoxSN, '') <> N'寄存仓批号'
                                        AND ISNULL(a.IsCancel, 0) = 0
                              GROUP BY  a.ProductId, a.LotSN
                              UNION ALL
                              -- 备料单
                              SELECT    a.ProductId, a.LotSN, SUM(a.Qty) AS Scanqty
                              FROM      dbo.StockListItemLot a WITH ( NOLOCK )
                              INNER JOIN dbo.StockListItem b WITH ( NOLOCK )
                                  ON b.StockListItemId = a.StockListItemId
                              WHERE     ISNULL(@StockListId, '') <> ''
                                        AND b.StockListId = @StockListId
                                        AND ISNULL(a.BoxSN, '') <> N'寄存仓批号'
                                        AND ISNULL(a.IsBack, 0) = 0
                              GROUP BY  a.ProductId, a.LotSN
                            ) x
                  GROUP BY  x.ProductId, x.LotSN
                ) v
        GROUP BY v.ProductId;

        SELECT  @AllPackQty = SUM(IssuedQty)
        FROM    KDMOItem
        WHERE   KDOrderItemId = @KDOrderItemId;

        UPDATE  a
        SET     a.ItemQtyRequired = ISNULL(b.Scanqty, 0)
        FROM    KDOrderItem a
        LEFT JOIN @MaterialScanqty b ON a.ProductId = b.Productid
        WHERE   a.KDOrderInfoId = @KDOrderInfoId AND ISNULL(b.Scanqty, 0) = 0 AND a.ItemQtyRequired = 0;

        UPDATE  a
        SET     a.ItemQtyRequired = IIF(ISNULL(@AllPackQty, 0) > ISNULL(b.Scanqty, 0), @AllPackQty, ISNULL(b.Scanqty, 0))
        FROM    KDOrderItem a
        LEFT JOIN @MaterialScanqty b ON a.ProductId = b.Productid
        WHERE   a.KDOrderItemId = @KDOrderItemId;

        DELETE  FROM dbo.locktable
        WHERE   lockflag = @lockFlag;

        SELECT  '' AS ScanSN, @ScanQty AS ScanQty;
        SET @I_ExceptionFieldName = 'ScanSN';
        SET @I_ReturnMessage = 'ServerMessage: 装箱成功, 请扫描下一个物料!';

        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        --异常时释放业务锁，避免锁泄漏导致后续装箱一直被拦
        IF ISNULL(@lockFlag, '') <> ''
        BEGIN
            DELETE  FROM dbo.locktable
            WHERE   lockflag = @lockFlag;
        END;

        INSERT INTO dbo.SqlProcedureIssueLog
        (
            ProcName, IssueType, StepCode, Message,
            ErrNumber, ErrLine, ErrMessage, OrBitUserId
        )
        VALUES
        (
            'PDA_CKDPacking_YN', N'SQL_EXCEPTION', N'CATCH',
            N'CKD装箱异常', @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId
        );

        SET @I_ReturnMessage = 'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;


