
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016  1:09PM>
-- Description:	为KDOrderModuleItem创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDOrderItemTreeView]
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_FiltCondition NVARCHAR(MAX) = '' ,	--过滤条件表达式
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = ''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.
AS
BEGIN
	-- This Stored Procedure is created by OrBit-MetaObject engine	
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	--执行TreeView,注意：以下过程必须根据业务的需求进行调整
	--如果您不了解TreeView过程如何编写，请参考我们提供的示例_SampleProjectTreeView

	--yxy  越南退料

	  DECLARE @OrderName1 NVARCHAR(50)=''
	SELECT @OrderName1=a.OrderName FROM dbo.KDOrderInfo  a
	WHERE a.KDOrderInfoId=@I_ParentPKId


	IF (@OrderName1='JB2025111111-1')
	BEGIN 

	SELECT b.* FROM dbo.KDOrderInfo  a
	LEFT JOIN dbo.KDOrderItem b ON b.KDOrderInfoId = a.KDOrderInfoId  
	WHERE a.KDOrderInfoId=@I_ParentPKId

	RETURN 0
	END
	--yxy

	--SELECT   
	--	TA.KDOrderItemId,
	--	TA.ProductId,	
	--	TA.ModuleName,	
	--	TA.CustomerNumber,
	--	TA.EnglishDescription,
	--	IIF(TA.Isvalidity=1,'√','') AS Isvalidity,	
	--	[dbo].[RemoveZero](ProductRoot.ProductName) as ProductName,
	--	Product.ProductDescription,
	--	UOM.UOMName,
	--	Convert(float,TA.BOMQtyRequired) as BOMQtyRequired,
	--	Convert(float,TA.QtyPack) as QtyPack,
	--	Convert(float,TA.ItemQtyRequired) as ItemQtyRequired,
	--	Convert(float,ISNULL(T2.IsPackQty,0)) as IsPackQty,
	--	Convert(float,ISNULL(T3.IsInStorageQty,0)) as IsInStorageQty,
	--	Convert(float,ISNULL(T4.IsOutStorageQty,0)) as IsOutStorageQty,
	--	SysUser1.UserName as OQCAffirmUserName,
	--	CASE TA.OQCAffirmResult when '1' then '合格' when '2' then '不合格' else '' end as OQCAffirmResult, 
	--	TA.OQCAffirmDate,
	--	SysUser2.UserName as OQAAffirmUserName,
	--	CASE TA.OQAAffirmResult when '1' then '合格' when '2' then '不合格' else '' end as OQAAffirmResult, 
	--	TA.OQAAffirmDate,
	--	case
	--		when ISNULL(TA.IsIgnore,0)=1 then '[RowColor:X3]'
	--		when ISNULL(T2.IsPackQty,0)<ISNULL(Convert(float,TA.ItemQtyRequired),0) then '[ItemQtyRequired:Y4]'
	--		when ISNULL(T2.IsPackQty,0)>=ISNULL(Convert(float,TA.ItemQtyRequired),0) then '[ItemQtyRequired:YD]'	
	--		else ''  end as ColorControlId
	--FROM   KDOrderItem TA
	--inner join KDOrderInfo on KDOrderInfo.KDOrderInfoId=TA.KDOrderInfoId
	--inner join Product on Product.ProductId=TA.ProductId
	--inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
	--left join UOM on UOM.UOMId=TA.UOMId
	--LEFT OUTER JOIN (SELECT SUM(ISNULL(RealQty, 0)) AS IsPackQty,KDBoxItem.KDOrderInfoId,KDBoxItem.ModuleName,KDBoxItem.ProductId
	--	FROM  KDBoxItem
	--	inner join KDBoxInfo on KDBoxInfo.KDBoxInfoId=KDBoxItem.KDBoxInfoId and KDBoxInfo.IsBox=0 and KDBoxInfo.IsCancel=0 and KDBoxItem.IsCancel=0
	--	 GROUP BY KDBoxItem.KDOrderInfoId,KDBoxItem.ModuleName,KDBoxItem.ProductId) AS T2 ON T2.KDOrderInfoId = TA.KDOrderInfoId 
	--	and T2.ModuleName=TA.ModuleName and T2.ProductId=TA.ProductId
	--LEFT OUTER JOIN (SELECT SUM(KDBoxItem.RealQty) as IsInStorageQty,KDPalletInfo.KDOrderInfoId,KDBoxItem.ProductId
	--	FROM KDPalletInfo
	--	inner join ShipPallet on ShipPallet.PalletSN=KDPalletInfo.PalletSN and ShipPallet.IsCancel=0
	--	inner join KDBoxInfo on KDBoxInfo.BoxSN=ShipPallet.BoxSN and KDBoxInfo.IsCancel=0 and IsBox=0
	--	inner join KDBoxItem on KDBoxItem.KDBoxInfoId=KDBoxInfo.KDBoxInfoId  and KDBoxItem.IsCancel=0 
	--	WHERE KDPalletInfo.StorageStatus in ('1','2')
	--	GROUP BY KDPalletInfo.KDOrderInfoId,KDBoxItem.ProductId) AS T3 ON T3.KDOrderInfoId=TA.KDOrderInfoId and T3.ProductId=TA.ProductId
	--LEFT OUTER JOIN (SELECT SUM(KDBoxItem.RealQty) as IsOutStorageQty,KDPalletInfo.KDOrderInfoId,KDBoxItem.ProductId
	--	FROM KDPalletInfo
	--	inner join ShipPallet on ShipPallet.PalletSN=KDPalletInfo.PalletSN and ShipPallet.IsCancel=0
	--	inner join KDBoxInfo on KDBoxInfo.BoxSN=ShipPallet.BoxSN and KDBoxInfo.IsCancel=0 and IsBox=0
	--	inner join KDBoxItem on KDBoxItem.KDBoxInfoId=KDBoxInfo.KDBoxInfoId  and KDBoxItem.IsCancel=0
	--	WHERE KDPalletInfo.StorageStatus='2'
	--	GROUP BY KDPalletInfo.KDOrderInfoId,KDBoxItem.ProductId) AS T4 ON T4.KDOrderInfoId=TA.KDOrderInfoId and T4.ProductId=TA.ProductId
	--left join SysUser SysUser1 on SysUser1.UserId=TA.OQCAffirmUserId
	--left join SysUser SysUser2 on SysUser2.UserId=TA.OQAAffirmUserId
	--where TA.KDOrderInfoId=@I_ParentPKId and TA.IsIgnore=0
	--order by IsIgnore,ModuleName
    
    IF @I_PlugInCommand = 'KDYN'
    BEGIN
        DECLARE @MaterialIssuanceID CHAR(12);
        DECLARE @ordername NVARCHAR(20);
		
        SELECT  @MaterialIssuanceID = CreateUserId, @ordername = OrderName
        FROM    KDOrderInfo
        WHERE   KDOrderInfoId = @I_ParentPKId;

		
		-- 创建临时表存储历史批次包装数量
        DECLARE @HistoryPackQty TABLE
            (
              ProductId VARCHAR(12) ,
              TotalPackQty DECIMAL(18, 4)
            );

		-- 当不是第一批次时，统计历史批次包装数量
        IF RIGHT(@ordername, 2) <> '-1'
        BEGIN
            INSERT  INTO @HistoryPackQty ( ProductId, TotalPackQty )
                    SELECT  b.ProductId, SUM(ISNULL(c.IssuedQty, 0)) AS TotalPackQty
                    FROM    KDOrderInfo a WITH ( NOLOCK )
                    INNER JOIN KDOrderItem b WITH ( NOLOCK ) ON a.KDOrderInfoId = b.KDOrderInfoId
                    INNER JOIN KDMOItem c WITH ( NOLOCK ) ON b.KDOrderItemId = c.KDOrderItemId
                    WHERE   a.OrderName LIKE LEFT(@ordername, LEN(@ordername) - 2) + '%' AND a.OrderName < @ordername
                    GROUP BY b.ProductId;
        END;

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

        --INSERT  INTO @MaterialScanqty ( MaterialIssuanceID, MaterialIssuanceItemID, Productid, Scanqty )
        --        SELECT  b.MaterialIssuanceID, a.MaterialIssuanceItemID, a.ProductId,
        --                SUM(Qty + ISNULL(a.Allotqty, 0)) AS Scanqty
        --        FROM    dbo.MaterialIssuanceItemLot a WITH ( NOLOCK )
        --        INNER JOIN dbo.MaterialIssuanceItem b ON b.MaterialIssuanceItemID = a.MaterialIssuanceItemID
        --        WHERE   b.MaterialIssuanceID = @MaterialIssuanceID AND ISNULL(a.BoxSN, '') <> '寄存仓批号' AND a.IsCancel=0
        --        GROUP BY b.MaterialIssuanceID, a.MaterialIssuanceItemID, a.ProductId;
		
        DECLARE @DepositMaterialScanqty TABLE
            (
              MaterialIssuanceID VARCHAR(12) ,
              MaterialIssuanceItemID VARCHAR(12) ,
              Productid VARCHAR(12) ,
              Scanqty DECIMAL(18, 4)
            );
        INSERT  INTO @DepositMaterialScanqty ( MaterialIssuanceID, MaterialIssuanceItemID, Productid, Scanqty )
                SELECT  b.MaterialIssuanceID, a.MaterialIssuanceItemID, a.ProductId,
                        SUM(Qty + ISNULL(a.Allotqty, 0)) AS Scanqty
                FROM    dbo.MaterialIssuanceItemLot a WITH ( NOLOCK )
                INNER JOIN dbo.MaterialIssuanceItem b ON b.MaterialIssuanceItemID = a.MaterialIssuanceItemID
                WHERE   b.MaterialIssuanceID = @MaterialIssuanceID AND ISNULL(a.BoxSN, '') = '寄存仓批号'
                GROUP BY b.MaterialIssuanceID, a.MaterialIssuanceItemID, a.ProductId;

				

		



		--IF @I_OrBitUserName = '2061399'
		--BEGIN
		--	SELECT b.prdname, a.* FROM @MaterialScanqty a INNER JOIN product b ON b.ProductId = a.Productid
		-- --   SELECT * FROM @DepositMaterialScanqty a INNER JOIN product b ON b.ProductId = a.Productid WHERE b.prdname='311812R0501y'
			
		--END
        
		UPDATE a SET a.oldQty = a.ItemQtyRequired,a.ItemQtyRequired = 0
		from KDOrderItem a 
		LEFT JOIN @MaterialScanqty b ON b.Productid = a.ProductId WHERE  a.KDOrderInfoId = @I_ParentPKId AND  b.Productid IS NULL  ---未发料

        UPDATE  a
        SET     a.ItemQtyRequired = ISNULL(b.Scanqty, 0)
        FROM    KDOrderItem a
        LEFT JOIN @MaterialScanqty b ON a.ProductId = b.Productid
        WHERE   a.KDOrderInfoId = @I_ParentPKId AND ISNULL(b.Scanqty, 0) = 0 --AND ISNULL(a.ItemQtyRequired, 0) = 0
                AND a.ProductId IN ( SELECT DISTINCT
                                            Productid
                                     FROM   @DepositMaterialScanqty );
		
        UPDATE  a
        SET     a.ItemQtyRequired = ISNULL(b.Scanqty, 0)
        FROM    KDOrderItem a
        left JOIN @MaterialScanqty b ON a.ProductId = b.Productid
        WHERE   a.KDOrderInfoId = @I_ParentPKId  --AND ISNULL(b.Scanqty, 0) > a.ItemQtyRequired;
	
        --UPDATE  a
        --SET     a.ItemQtyRequired = b.PackQty
        --FROM    KDOrderItem a
        --INNER JOIN (
        --             SELECT c.KDOrderItemId, SUM(ISNULL(c.IssuedQty, 0)) AS PackQty
        --             FROM   KDMOItem c
        --             INNER JOIN KDOrderItem d ON c.KDOrderItemId = d.KDOrderItemId
        --             WHERE  d.KDOrderInfoId = @I_ParentPKId
        --             GROUP BY c.KDOrderItemId
        --           ) b ON a.KDOrderItemId = b.KDOrderItemId
        --WHERE   a.KDOrderInfoId = @I_ParentPKId --AND a.ItemQtyRequired < b.PackQty;





		
        UPDATE  a
        SET     a.OQAAffirmResult = 1
        FROM    KDOrderItem a WITH ( NOLOCK )
        WHERE   KDOrderItemId IN ( SELECT   a.KDOrderItemId
                                   FROM     KDOrderItem a WITH ( NOLOCK )
                                   INNER JOIN KDMOItem c WITH ( NOLOCK ) ON a.KDOrderItemId = c.KDOrderItemId
                                   WHERE    a.KDOrderInfoId = @I_ParentPKId
                                   GROUP BY a.KDOrderItemId, a.ItemQtyRequired
                                   HAVING   a.ItemQtyRequired <= SUM(ISNULL(c.IssuedQty, 0)) );
	  	    
       ---------------这里不要随便修改 ，不然会影响 生成下一批次的功能  CopyKDOrderInfoDoMethod  --------------------------------------------------------
	    SELECT  a.KDOrderItemId, b.prdname, a.IsValidity, b.ProductDescription, b.EngDesc, d.UOMName,
                SUM(IIF(ISNULL(c.MOItemId, '') = '', 0, c.ItemQtyRequired)) AS ItemQtyRequired,
                a.ItemQtyRequired - ISNULL(h.TotalPackQty, 0) AS ItemIssuedQty, SUM(ISNULL(c.IssuedQty, 0)) AS IsPackQty,
                e.Scanqty AS '出寄存仓数量'
				--, IIF(a.ItemQtyRequired <= SUM(ISNULL(c.IssuedQty, 0)), 'PASS', 'NG') AS '包装状态',
					, IIF(a.ItemQtyRequired <= SUM(ISNULL(c.IssuedQty, 0)), 'PASS', 'NG') AS '包装状态',
                CASE WHEN a.ItemQtyRequired  > SUM(ISNULL(c.IssuedQty, 0)) THEN '[RowColor:Y4Z]'
                     WHEN a.ItemQtyRequired <= SUM(ISNULL(c.IssuedQty, 0)) THEN '[RowColor:YDZ]'
                     ELSE ''
                END AS ColorControlId
        FROM    KDOrderItem a WITH ( NOLOCK )
        INNER JOIN Product b WITH ( NOLOCK ) ON a.ProductId = b.ProductId
        INNER JOIN KDMOItem c WITH ( NOLOCK ) ON a.KDOrderItemId = c.KDOrderItemId
        INNER JOIN UOM d WITH ( NOLOCK ) ON b.UsageUOMId = d.UOMId
        LEFT JOIN @DepositMaterialScanqty e ON b.ProductId = e.Productid
        LEFT JOIN @HistoryPackQty h ON b.ProductId = h.ProductId -- 关联历史批次数量
        WHERE   a.KDOrderInfoId = @I_ParentPKId
        GROUP BY a.KDOrderItemId, a.IsValidity, a.ItemQtyRequired, b.prdname, b.ProductDescription, b.EngDesc, d.UOMName, e.Scanqty,
                h.TotalPackQty -- 添加分组字段
        ORDER BY SUM(ISNULL(c.IssuedQty, 0)) DESC;
	      ---------------这里不要随便修改 ，不然会影响 生成下一批次的功能 ---------------------------------------------------------------------------------

        RETURN 0;
    END; 

    SELECT  TA.KDOrderItemId, TA.KDOrderInfoId, TA.ProductId, TA.ModuleName, TA.CustomerNumber, TA.EnglishDescription,
            TA.FieldsA, ProductRoot.ProductWeight, IIF(TA.IsValidity = 1, '√', '') AS Isvalidity,
            [dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, Product.ProductDescription, UOM.UOMName,
            CONVERT(FLOAT, TA.BOMQtyRequired) AS BOMQtyRequired, CONVERT(FLOAT, TA.QtyPack) AS QtyPack,
            CONVERT(FLOAT, TA.ItemQtyRequired) AS ItemQtyRequired, CONVERT(FLOAT, TA.SingleWeight) AS SingleWeight,
            SysUser1.UserName AS OQCAffirmUserName, CASE TA.OQCAffirmResult
                                                      WHEN '1' THEN '合格'
                                                      WHEN '2' THEN '不合格'
                                                      ELSE ''
                                                    END AS OQCAffirmResult, TA.OQCAffirmDate,
            SysUser2.UserName AS OQAAffirmUserName, CASE TA.OQAAffirmResult
                                                      WHEN '1' THEN '合格'
                                                      WHEN '2' THEN '不合格'
                                                      ELSE ''
                                                    END AS OQAAffirmResult, TA.OQAAffirmDate, TA.IsIgnore
    INTO    #KDOrderItem
    FROM    KDOrderItem TA
    INNER JOIN KDOrderInfo ON KDOrderInfo.KDOrderInfoId = TA.KDOrderInfoId
    INNER JOIN Product ON Product.ProductId = TA.ProductId
    INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
    LEFT JOIN UOM ON UOM.UOMId = TA.UOMId
    LEFT JOIN SysUser SysUser1 ON SysUser1.UserId = TA.OQCAffirmUserId
    LEFT JOIN SysUser SysUser2 ON SysUser2.UserId = TA.OQAAffirmUserId
    WHERE   TA.KDOrderInfoId = @I_ParentPKId AND TA.IsIgnore = 0
    ORDER BY IsIgnore, ModuleName;

	
    SELECT  ISNULL(SUM(RealQty), 0) AS IsPackQty, KDBoxItem.KDOrderInfoId, KDBoxItem.ModuleName, KDBoxItem.ProductId
    INTO    #T2
    FROM    KDBoxItem
    INNER JOIN KDBoxInfo ON KDBoxInfo.KDBoxInfoId = KDBoxItem.KDBoxInfoId AND KDBoxInfo.IsCancel = 0 AND KDBoxItem.IsCancel = 0 -- and KDBoxInfo.IsBox=0 
    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId
    GROUP BY KDBoxItem.KDOrderInfoId, KDBoxItem.ModuleName, KDBoxItem.ProductId;
	

    SELECT  ISNULL(SUM(KDBoxItem.RealQty), 0) AS IsInStorageQty, KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId
    INTO    #T3
    FROM    KDPalletInfo
    INNER JOIN ShipPallet ON ShipPallet.PalletSN = KDPalletInfo.PalletSN AND ShipPallet.IsCancel = 0
    INNER JOIN KDBoxInfo ON KDBoxInfo.BoxSN = ShipPallet.BoxSN AND KDBoxInfo.IsCancel = 0 AND IsBox = 0
    INNER JOIN KDBoxItem ON KDBoxItem.KDBoxInfoId = KDBoxInfo.KDBoxInfoId AND KDBoxItem.IsCancel = 0
    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId AND KDPalletInfo.StorageStatus IN ( '1', '2' )
    GROUP BY KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId;

    SELECT  ISNULL(SUM(KDBoxItem.RealQty), 0) AS IsOutStorageQty, KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId
    INTO    #T4
    FROM    KDPalletInfo
    INNER JOIN ShipPallet ON ShipPallet.PalletSN = KDPalletInfo.PalletSN AND ShipPallet.IsCancel = 0
    INNER JOIN KDBoxInfo ON KDBoxInfo.BoxSN = ShipPallet.BoxSN AND KDBoxInfo.IsCancel = 0 AND IsBox = 0
    INNER JOIN KDBoxItem ON KDBoxItem.KDBoxInfoId = KDBoxInfo.KDBoxInfoId AND KDBoxItem.IsCancel = 0
    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId AND KDPalletInfo.StorageStatus = '2'
    GROUP BY KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId;

	

    SELECT  TA.KDOrderItemId, TA.ProductId, TA.ModuleName, TA.CustomerNumber, TA.EnglishDescription, TA.Isvalidity,
            TA.ProductName, TA.ProductDescription, TA.FieldsA, TA.ProductWeight, TA.UOMName,
            CONVERT(FLOAT, TA.BOMQtyRequired) AS BOMQtyRequired, CONVERT(FLOAT, TA.QtyPack) AS QtyPack,
            CONVERT(FLOAT, TA.ItemQtyRequired) AS ItemQtyRequired, TA.SingleWeight,
            CONVERT(FLOAT, ISNULL(T2.IsPackQty, 0)) AS IsPackQty,
            CONVERT(FLOAT, ISNULL(T3.IsInStorageQty, 0)) AS IsInStorageQty,
            CONVERT(FLOAT, ISNULL(T4.IsOutStorageQty, 0)) AS IsOutStorageQty, TA.OQCAffirmUserName, TA.OQCAffirmResult,
            TA.OQCAffirmDate, TA.OQAAffirmUserName, TA.OQAAffirmResult, TA.OQAAffirmDate,
            CASE WHEN ISNULL(TA.IsIgnore, 0) = 1 THEN '[RowColor:X3]'
                 WHEN ISNULL(T2.IsPackQty, 0) < ISNULL(CONVERT(FLOAT, TA.ItemQtyRequired), 0)
                 THEN '[ItemQtyRequired:Y4]'
                 WHEN ISNULL(T2.IsPackQty, 0) >= ISNULL(CONVERT(FLOAT, TA.ItemQtyRequired), 0)
                 THEN '[ItemQtyRequired:YD]'
                 ELSE ''
            END AS ColorControlId
    FROM    #KDOrderItem TA
    LEFT JOIN #T2 T2 ON T2.KDOrderInfoId = TA.KDOrderInfoId AND T2.ModuleName = TA.ModuleName AND T2.ProductId = TA.ProductId
    LEFT JOIN #T3 T3 ON T3.KDOrderInfoId = TA.KDOrderInfoId AND T3.ProductId = TA.ProductId
    LEFT JOIN #T4 T4 ON T4.KDOrderInfoId = TA.KDOrderInfoId AND T4.ProductId = TA.ProductId
	
    ORDER BY TA.IsIgnore, TA.ModuleName
	

    DROP TABLE #KDOrderItem,#T2,#T3,#T4;

    RETURN 0;
	
END;

