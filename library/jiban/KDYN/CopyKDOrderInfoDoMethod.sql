-- =============================================
-- Author:		<OrBit trae ai>
-- Create date: <2025.04.22>
-- Description:	生成越南CKD订单信息，根据发料单生成装箱订单
-- =============================================
CREATE PROCEDURE [dbo].[CopyKDOrderInfoDoMethod]
    @I_Sender NVARCHAR(200) = '',
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,
    @I_LanguageId CHAR(1) = '1',
    @I_PlugInCommand VARCHAR(5) = '',
    @I_OrBitUserId CHAR(12) = '',
    @I_OrBitUserName NVARCHAR(100) = '',
    @I_ResourceId CHAR(12) = '',
    @I_ResourceName NVARCHAR(100) = '',
    @I_PKid CHAR(12) = '',
    @I_ParentPKId CHAR(12) = '',
    @I_Parameter NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @KDOrderInfoId CHAR(12);
	DECLARE @oldKdorderinfoid CHAR(12);
    DECLARE @OrderName VARCHAR(50);
    DECLARE @SOName VARCHAR(50);
    DECLARE @MaterialIssuanceID CHAR(12);
    DECLARE @MOId CHAR(12);
    DECLARE @KDMOId CHAR(12);
    DECLARE @MOQtyRequired DECIMAL(18, 4);

    -- 获取原订单信息
    SELECT @oldKdorderinfoid = KDOrderInfoId, 
           @OrderName = OrderName, 
           @SOName = SOName,
           @MaterialIssuanceID = CreateUserId
    FROM KDOrderInfo
    WHERE KDOrderInfoId = @I_ParentPKId;

	IF NOT EXISTS(SELECT 1 FROM dbo.KDBoxItem WHERE KDOrderInfoId=@oldKdorderinfoid)
	BEGIN
		SET @I_ReturnMessage = '当前订单未包装，无法生成下一批次';
		RETURN -1

	END
    
	IF @I_PlugInCommand <> 'KDYN'
	BEGIN
		SET @I_ReturnMessage = '请在插件KDYN中操作';
		RETURN -1
	END

	--IF NOT EXISTS(
	--SELECT 1 FROM dbo.KDOrderItem WHERE KDOrderInfoId=@oldKdorderinfoid AND OQAAffirmResult =0 
	--)
	--BEGIN
	--	SET @I_ReturnMessage ='ServerMessage: 没有需要生成的批次物料';
	--	RETURN -1

	--END
    


    -- 生成新订单号
    DECLARE @NewOrderNo VARCHAR(50);
    SET @NewOrderNo = LEFT(@OrderName, 12) + '-' + 
                     CONVERT(VARCHAR(10), CAST(RIGHT(@OrderName, 1) AS INT) + 1);

    -- 创建新订单
    EXEC SysGetObjectPKId '', 'KDOrderInfo', @KDOrderInfoId OUTPUT;

    INSERT INTO dbo.KDOrderInfo(
        KDOrderInfoId, OrderName, SOName, 
        OrderDescription, OrderType, CreateUserId
    )
    VALUES(
        @KDOrderInfoId, @NewOrderNo, 
        SUBSTRING(@NewOrderNo, 3, 10), 
        '越南CKD包装订单', '9', @MaterialIssuanceID
    );

    -- 复制工单信息
    DECLARE MOCursor CURSOR FOR
    SELECT a.MOId, b.MOQtyRequired 
    FROM dbo.MaterialIssuanceMO a
    INNER JOIN MO b ON a.MOId = b.MOId
    WHERE MaterialIssuanceId = @MaterialIssuanceID;
    
    OPEN MOCursor;
    FETCH NEXT FROM MOCursor INTO @MOId, @MOQtyRequired;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (
            SELECT 1 
            FROM dbo.KDMO 
            WHERE KDOrderInfoId = @KDOrderInfoId 
            AND MOId = @MOId
        )
        BEGIN
            EXEC SysGetObjectPKId '', 'KDMO', @KDMOId OUTPUT;
            
            INSERT INTO dbo.KDMO (
                KDMOId, KDOrderInfoId, MOId, 
                MOPackQty, IsExpand
            )
            VALUES(
                @KDMOId, @KDOrderInfoId, @MOId, 
                @MOQtyRequired, 1
            );
        END;

        FETCH NEXT FROM MOCursor INTO @MOId, @MOQtyRequired;
    END;
    
    CLOSE MOCursor;
    DEALLOCATE MOCursor;


    -- 展开工单明细
    EXEC dbo.KDOrderExpandItemDoMethod 
        @I_ParentPKId = @KDOrderInfoId,
        @I_PKId = @KDOrderInfoId,
        @I_PlugInCommand = 'KDYN',
        @I_OrBitUserId = 'SUR1000005OZ',
        @I_OrBitUserName = 'mes',
        @I_Sender = 'ExpandMOItem';

SELECT * FROM dbo.KDOrderItem WHERE ProductId='PRD10000HRT6'
		----------------------------------------------------
CREATE TABLE #temptable ( [KDOrderItemId] char(12), [prdname] nvarchar(50),isvalidity NVARCHAR(50), [ProductDescription] nvarchar(500), [EngDesc] nvarchar(300), [UOMName] nvarchar(50), [ItemQtyRequired] decimal(38,4), [ItemIssuedQty] decimal(18,2), [IsPackQty] decimal(38,4), [出寄存仓数量] decimal(18,4), [包装状态] varchar(4), [ColorControlId] varchar(14) )
INSERT INTO #temptable
	EXEC dbo.KDOrderItemTreeView @I_ReturnMessage = @I_ReturnMessage OUTPUT, -- nvarchar(max)
	                             @I_LanguageId = '',                         -- char(1)
	                             @I_PlugInCommand = 'kdyn',                      -- varchar(5)
	                             @I_FiltCondition = N'',                     -- nvarchar(max)
	                             @I_OrBitUserId = '',                        -- char(12)
	                             @I_OrBitUserName = N'',                     -- nvarchar(100)
	                             @I_ResourceId = '',                         -- char(12)
	                             @I_ResourceName = N'',                      -- nvarchar(100)
	                             @I_PKId = '',                               -- char(12)
	                             @I_ParentPKId = @oldKdorderinfoid,                         -- char(12)
	                             @I_Parameter = N''                          -- nvarchar(100)
	
	

	SELECT * FROM #temptable WHERE prdname='205C1902002Y'
	--RETURN 
	--SELECT ItemQtyRequired,ISNULL(出寄存仓数量,0)+ IsPackQty AS '出寄存仓数量+ IsPackQty',出寄存仓数量,IsPackQty FROM #temptable

	SELECT prdname
	INTO #tmpPrd
	 FROM #temptable WHERE ItemQtyRequired > ISNULL(出寄存仓数量,0)+ IsPackQty   --NG

	 INSERT INTO #tmpPrd
	 (
	     prdname
	 )
	 VALUES
	 (N'205C1902002Y' -- prdname - nvarchar(50)
	     )


	 SELECT '生成下一批次物料',* FROM #tmpPrd

	 	INSERT INTO KDOrderItem_log
	SELECT a.* FROM dbo.KDOrderItem a 
	LEFT JOIN #tmpPrd b ON b.prdname=a.ModuleName
	WHERE a.KDOrderInfoId=@KDOrderInfoId  AND b.prdname IS NULL 
 
	SELECT '删除日志', a.* FROM dbo.KDOrderItem a 
	LEFT JOIN #tmpPrd b ON b.prdname=a.ModuleName
	WHERE a.KDOrderInfoId=@KDOrderInfoId  AND b.prdname IS NULL 
	
	SELECT '1',* FROM dbo.KDOrderItem a INNER JOIN #tmpPrd b ON b.prdname=a.ModuleName WHERE a.KDOrderInfoId=@KDOrderInfoId
	SELECT '2',* FROM dbo.KDOrderItem a INNER JOIN #tmpPrd b ON b.prdname=a.CustomerNumber  WHERE a.KDOrderInfoId=@KDOrderInfoId


    -- 保留未发料的 物料
	DELETE a 
	 FROM dbo.KDOrderItem a 
	LEFT JOIN #tmpPrd b ON b.prdname=a.ModuleName
	WHERE a.KDOrderInfoId=@KDOrderInfoId  AND b.prdname IS NULL 



    
	-- 修改物料 数量
	UPDATE a SET a.ItemQtyRequired=b.ItemIssuedQty FROM dbo.KDOrderItem a
	INNER JOIN #temptable b ON b.prdname=a.ModuleName
	 WHERE a.KDOrderInfoId=@KDOrderInfoId


	--需要将未装箱的箱号移动至下一批次
	UPDATE a SET a.KDOrderInfoId=@KDOrderInfoId,a.OrderName=@NewOrderNo
	 FROM dbo.KDBoxInfo a 
	LEFT JOIN dbo.KDBoxItem b ON b.KDBoxInfoId = a.KDBoxInfoId AND b.IsCancel=0
	WHERE a.KDOrderInfoId =@oldKdorderinfoid AND a.IsCancel=0 AND b.KDBoxItemId IS NULL 

	UPDATE a SET a.KDOrderInfoId = @KDOrderInfoId,a.OrderName=@NewOrderNo
	FROM dbo.KDPalletInfo a 
	LEFT JOIN dbo.ShipPallet b ON b.PalletSN=a.PalletSN AND b.IsCancel=0
	WHERE a.KDOrderInfoId=@oldKdorderinfoid AND a.IsCancel=0 AND b.ShipPalletId IS NULL


    SET @I_ReturnMessage = 'ServerMessage:批次订单['+@NewOrderNo+']生成成功！请刷新';
    RETURN 0;
END;
