
-- =============================================
-- Author:		<Orbit Team Phoenix>
-- Create date: <2021.08.03>
-- Description:	SKD散件订单汇出
-- =============================================
CREATE PROCEDURE [dbo].[Query_SKDSJReportForYNNewOutDoMethod]
    @I_Sender NVARCHAR(200) = '' ,			--客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,		--返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT ,	--向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,			--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKid CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数
    
 --以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @StartPalletSn VARCHAR(50) = '' ,
    @EndPalletSn VARCHAR(50) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
    DECLARE @KDOrderName NVARCHAR(50);
    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @ItemNoShowI INT = 0;
    DECLARE @ItemNoShowOld NVARCHAR(50)= '';
    DECLARE @ItemNo INT = 0;
    DECLARE @ItemNoShow NVARCHAR(50)= '';
    DECLARE @ItemOrder NVARCHAR(200)= '';
	--DECLARE @OrderDescription NVARCHAR(50)=''
    DECLARE @TempKDOrderInfoId TABLE ( KDOrderInfoId CHAR(12) );
	
    IF ISNULL(@I_PKid, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择订单号!';
        RETURN -1;
    END;

    SELECT  @KDOrderName = OrderName, @KDOrderInfoId = KDOrderInfoId--,@OrderDescription=OrderDescription
    FROM    dbo.KDOrderInfo
    WHERE   KDOrderInfoId = @I_PKid;

    IF ISNULL(@KDOrderInfoId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:未找到匹配的SKD散件订单信息!';
        RETURN -1;
    END;

 
    SELECT  '' AS BookingNumber, '' AS TransCompany, '' AS ComAdhBoard, '' AS SparePartsFlag,
            CONVERT(NVARCHAR, '', 23) AS PlanTime, '' AS CabinetNumber, '' AS CabinetType,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, 0)), '') AS PalletWeight, '' AS SparePartsNum,
            CONVERT(NVARCHAR, '', 23) AS ArrivalTime, '' AS SealNumber,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, 0)), '') AS CabinetWeight, '' AS PalletNumber,
            '' AS SparePartsPalNum, CONVERT(NVARCHAR, '', 23) AS LeftTime, REPLACE(T.OrderName, 'JB', '') AS OrderNo,
            T.CustomerName, '' AS CustomerModelNo, CONVERT(NVARCHAR, T.OrderQty) + 'PCS' AS OrderQty,
            T.ProductCode AS ProductsCode, CONVERT(NVARCHAR, T.OrderDate, 23) AS OrderDate, '' AS CustomerOrderNo,
            '' AS CustomerPoNo, T.Brand, '' AS Area, T.Panel, T.SKD, '' AS NoticeNo, '' AS SupplierId,
            '' AS SupplierName, '' AS BoxMessage, '' AS Preparer, CONVERT(NVARCHAR, '', 23) AS PreparationTime,
            '' AS Checker, CONVERT(NVARCHAR, '', 23) AS CheckTime, '' AS Approver,
            CONVERT(NVARCHAR, '', 23) AS ApprovalTime
    FROM    dbo.KDOrderInfo T
    WHERE   T.KDOrderInfoId = @I_PKid;

	--1. 栈板信息
    SELECT  a.PalletSN, COUNT(DISTINCT b.BoxSN) AS PalQty, 1 AS PalNum, a.L, a.W, a.H,
            SUM(ISNULL(c.NetWeight, 0)) AS TotalNw, a.PGROSSWEIGHT AS TotalGw
    INTO    #PP
    FROM    KDPalletInfo a
    INNER JOIN ShipPallet b ON a.PalletSN = b.PalletSN AND b.IsCancel = 0
    INNER JOIN KDBoxInfo c ON b.BoxSN = c.BoxSN
    WHERE   a.KDOrderInfoId = @I_PKid AND (
                                            a.PalletSN >= @StartPalletSn OR ISNULL(@StartPalletSn, '') = ''
                                          ) AND (
                                                  a.PalletSN <= @EndPalletSn OR ISNULL(@EndPalletSn, '') = ''
                                                )
    GROUP BY a.PalletSN, a.L, a.W, a.H, a.PGROSSWEIGHT;

	--2. 装箱数据-需要区分订单、组件、品牌、重量、大小
    SELECT  ISNULL(d.SOName, '') AS ProdOrderNo, g.prdname AS MtcComponent, b.prdname AS MtcPartNo,
            SUM(h.LotQty) AS BoxQty, COUNT(DISTINCT TF.BoxSN) AS BoxNum, SUM(h.LotQty) AS ItemQtyRequired, p.PalletSN,
            TF.BoxSN AS BoxSN, MIN(RIGHT(TF.BoxSN, 5)) AS BoxNoMin, MAX(RIGHT(TF.BoxSN, 5)) AS BoxNoMax,
            TF.BoxLength AS BoxL, TF.BoxWidth AS BoxW, TF.BoxHeight AS BoxH,
         	--TF.NetWeight AS BoxNw,
            SUM(h.LotQty) * ISNULL(MAX(j.UnitNetWeight), 0) / 1000.00 AS BoxNw, MAX(TF.GrossWeight) AS BoxGw,
            e.BOMQtyRequired, MAX(j.UnitNetWeight) AS UnitNetWeight,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5), MIN(RIGHT(TF.BoxSN, 5)) )
            AS ROWNUMA,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5) DESC, MIN(RIGHT(TF.BoxSN,
                                                                                                        5)) DESC ) AS ROWNUMD,
            MAX(GrossWeight) AS GrossWeight, k.UOMName AS DosageUnit, j.Brand,j.Country,
            ROW_NUMBER() OVER ( PARTITION BY ISNULL(d.SOName, ''), b.prdname ORDER BY p.PalletSN ) AS ItemNoShow,CAST('' AS NVARCHAR(50)) AS ProdCode,
			CASE 
				WHEN MAX(CAST(vd.NoBrand AS INT)) = 1 THEN '-' 
				ELSE j.Brand 
			END   as NoBrand 
    INTO    #AA
    FROM    KDBoxItem TI WITH ( NOLOCK )
    LEFT JOIN KDBoxInfo TF WITH ( NOLOCK ) ON TI.KDBoxInfoId = TF.KDBoxInfoId
    LEFT JOIN ShipBox sp WITH ( NOLOCK ) ON TF.BoxSN = sp.BoxSN AND TI.ProductId = sp.ProductId AND sp.IsCancel = 0
    LEFT JOIN ShipPallet p WITH ( NOLOCK ) ON p.BoxSN = TF.BoxSN AND p.IsCancel = 0
    LEFT JOIN dbo.Product b WITH ( NOLOCK ) ON b.ProductId = TI.ProductId
    LEFT JOIN dbo.KDOrderItem c WITH ( NOLOCK ) ON TF.KDOrderInfoId = c.KDOrderInfoId AND c.ProductId = TI.ProductId
    LEFT JOIN dbo.KDMOItem d WITH ( NOLOCK ) ON c.KDOrderItemId = d.KDOrderItemId
    LEFT JOIN dbo.MOItem e WITH ( NOLOCK ) ON d.MOItemId = e.MOItemId
    LEFT JOIN dbo.MO f WITH ( NOLOCK ) ON e.MOId = f.MOId
    LEFT JOIN dbo.Product g WITH ( NOLOCK ) ON f.ProductId = g.ProductId
    LEFT JOIN dbo.KDMOItemLot h WITH ( NOLOCK ) ON d.KDMOItemId = h.KDMOItemId AND sp.LotSN = h.LotSN AND h.IsCancel = 0
    LEFT JOIN dbo.WW_RMInventory i WITH ( NOLOCK ) ON sp.LotSN = i.LotSN
    LEFT JOIN dbo.Vendor_Product j WITH ( NOLOCK ) ON i.ProductId = j.ProductId AND i.VendorId = j.VendorId 
	LEFT JOIN dbo.VendorDeliveryItemLot vd WITH(nolock) ON vd.LotSN = i.LotSN AND vd.IsCancel=0
	LEFT JOIN dbo.UOM k WITH ( NOLOCK ) ON k.UOMId = c.UOMId
    WHERE   TF.KDOrderInfoId = @KDOrderInfoId AND TI.IsCancel = 0 AND TF.BoxNumber NOT LIKE 'SJ/%'
    GROUP BY d.SOName, b.prdname, g.prdname, e.BOMQtyRequired, p.PalletSN, TF.BoxSN, TF.BoxLength, TF.BoxWidth,
            TF.BoxHeight, k.UOMName, j.Brand,j.Country, TF.NetWeight
    HAVING  ISNULL(SUM(h.LotQty), 0) > 0;

	--IF @OrderDescription='墨西哥CKD包装订单'
	--BEGIN  
	--	 --FROM #AA a INNER JOIN dbo.Product b ON a.pr 
	--END 


	UPDATE #AA SET Brand=NoBrand
	
	UPDATE a
	SET a.ProdCode = D.prdname
	FROM #AA a
		INNER JOIN SO b
			ON a.ProdOrderNo = b.SOName
		CROSS APPLY
	(
		-- 取每个 SO 下【第一条】SOItem，按 LineSequence 排序
		SELECT TOP 1
			   c.ProductId
		FROM dbo.SOItem c
		WHERE c.SOId = b.SOId
		ORDER BY c.LineSequence ASC -- 000010 最小排最前
	) c
		INNER JOIN Product d
			ON c.ProductId = d.ProductId;

    /*SELECT  b.prdname AS ProductName, b.ProductDescription, TS.*, b.prdname AS ModuleSN, 
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY TS.KDOrderItemId ) AS ROWNUMA,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY TS.KDOrderItemId DESC ) AS ROWNUMD,
            b.EngDesc, c.SOName AS ProdOrderNo --, c.UnitNetWeight
    INTO    #AA
    FROM    dbo.KDOrderItem TS
    LEFT JOIN dbo.Product b ON b.ProductId = TS.ProductId
	LEFT JOIN dbo.KDMOItem c ON TS.KDOrderItemId = c.KDOrderItemId
    WHERE   TS.KDOrderInfoId = @KDOrderInfoId;*/

    SELECT  c.prdname AS MtcPartNo, c.EngDesc, c.ProductDescription
    INTO    #CC
    FROM    KDOrderItem TK
    LEFT JOIN dbo.Product c ON c.ProductId = TK.ProductId
    WHERE   TK.KDOrderInfoId = @KDOrderInfoId;

   	
    /*SELECT d.SOName AS ProdOrderNo,  b.prdname AS ModuleSN, TI.RealQty AS BoxQty, COUNT(DISTINCT TF.BoxSN) AS BoxNum,
            LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5) AS BoxSN, MIN(RIGHT(TF.BoxSN, 5)) AS BoxNoMin,
            MAX(RIGHT(TF.BoxSN, 5)) AS BoxNoMax, TF.BoxLength AS BoxL, TF.BoxWidth AS BoxW, TF.BoxHeight AS BoxH,
          	MAX(TF.NetWeight) AS BoxNw, MAX(TF.GrossWeight) AS BoxGw,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5), MIN(RIGHT(TF.BoxSN, 5)) )
            AS ROWNUMA,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5) DESC, MIN(RIGHT(TF.BoxSN,
        5)) DESC ) AS ROWNUMD,
            MAX(GrossWeight) AS GrossWeight,
            CAST(ROW_NUMBER() OVER(PARTITION BY d.SOName, b.prdname ORDER BY d.SOName) AS VARCHAR(10)) AS ItemNoShow
    INTO    #CC
    FROM    KDBoxItem TI
    LEFT JOIN KDBoxInfo TF ON TI.KDBoxInfoId = TF.KDBoxInfoId
    LEFT JOIN dbo.Product b ON b.ProductId = TI.ProductId
    LEFT JOIN dbo.KDOrderItem c ON TF.KDOrderInfoId = c.KDOrderInfoId
    LEFT JOIN dbo.KDMOItem d ON c.KDOrderItemId = d.KDOrderItemId
    WHERE   TF.KDOrderInfoId = @KDOrderInfoId
	AND TF.BoxNumber NOT LIKE 'SJ/%'
    GROUP BY d.SOName ,b.prdname, TI.RealQty, LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5), TF.BoxLength, TF.BoxWidth, TF.BoxHeight;*/

    SELECT  ROW_NUMBER() OVER ( ORDER BY PP.PalletSN, AA.BoxSN, ItemNoShow ) AS ItemNo, 
			ItemNoShow AS ItemNoShow, '' AS CustomerPI, '' AS CustomerCom, 'K' + AA.MtcPartNo AS CustomerProd,
            ISNULL(AA.MtcComponent, '') AS MtcComponent, AA.MtcPartNo AS MtcPartNo, CC.EngDesc AS SpecEnglish, 
			 -- 修改部分：如果DosageUnit为ML，则转换为L
             CASE WHEN AA.DosageUnit = 'ML' THEN 'L' ELSE AA.DosageUnit END AS DosageUnit,
			AA.Brand,
            CC.ProductDescription AS Specification, '' AS English,
            -- 修改部分：如果DosageUnit为ML，则DosageQty除以1000
            CASE 
            WHEN AA.DosageUnit = 'ML' THEN CAST(AA.BOMQtyRequired / 1000.0 AS FLOAT)
            ELSE CAST(AA.BOMQtyRequired AS FLOAT)
            END AS DosageQty,
			--FORMAT(AA.UnitNetWeight / 1000, '0.0000000') 
            CASE WHEN aa.MtcPartNo ='60103000023Y' THEN FORMAT(AA.UnitNetWeight  , '0.0000000')  ELSE  FORMAT(AA.UnitNetWeight / 1000, '0.0000000') END 
			AS SinWeight, 
			--AA.UnitNetWeight AS SinWeight,
			--CAST(CAST(cc.BoxNw / CC.BoxQty AS DECIMAL(18,2)) AS NVARCHAR(20)) AS SinWeight,
            -- 修改部分：如果DosageUnit为ML，则TotalQty除以1000
            CASE 
            WHEN AA.DosageUnit = 'ML' THEN CAST(AA.ItemQtyRequired / 1000.0 AS FLOAT)
            ELSE CAST(AA.ItemQtyRequired AS FLOAT)
            END AS TotalQty, 
			-- 修改部分：如果DosageUnit为ML，则BoxQty除以1000
			CASE 
				WHEN AA.DosageUnit = 'ML' THEN CAST(AA.BoxQty / 1000.0 AS FLOAT)
				ELSE CAST(AA.BoxQty AS FLOAT)
			END AS BoxQty,
            CAST(AA.BoxNum AS FLOAT) AS BoxNum,
--            ( CASE WHEN AA.BoxNum = 1 THEN ISNULL(CONVERT(NVARCHAR, AA.BoxSN + AA.BoxNoMin), '')
--                   ELSE ISNULL(CONVERT(NVARCHAR, AA.BoxSN + AA.BoxNoMin + '-' + AA.BoxNoMax), '')
--              END ) AS BoxNo, 
            AA.BoxSN AS BoxNo, CAST(AA.BoxL AS FLOAT) AS BoxL, CAST(AA.BoxW AS FLOAT) AS BoxW,
            CAST(AA.BoxH AS FLOAT) AS BoxH, 
			CAST(AA.BoxNw AS DECIMAL(18,5)) AS BoxNw, 
			CAST(AA.BoxGw AS DECIMAL(18,5)) AS BoxGw, 
--            --ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, PP.TotalNw)), '') AS TotalNw,
            CAST(AA.BoxNw AS DECIMAL(18,5)) AS TotalNw, 
			FORMAT(CAST(STR(PP.TotalGw, 10, 5) AS DECIMAL(18,5)), '0.#####') AS TotalGw,
            CAST(CAST(PP.L AS DECIMAL(18,5)) * CAST(PP.W AS DECIMAL(18,5)) * CAST(PP.H AS DECIMAL(18,5)) / 1000000000.0 AS DECIMAL(18,5)) AS TotalVol, '' AS Model,
            AA.ProdOrderNo AS ProdOrderNo, aa.ProdCode,
            CAST('' AS NVARCHAR(200)) AS ItemOrder,
            --AA.PalletSN AS ItemOrder,
            -- 修改部分：如果DosageUnit为ML，则BoxQty除以1000
			CASE 
				WHEN AA.DosageUnit = 'ML' THEN CAST(AA.BoxQty / 1000.0 AS FLOAT)
				ELSE CAST(AA.BoxQty AS FLOAT)
			END AS PalQty,
			PP.PalNum, PP.PalletSN AS PalNO, PP.L AS PalL, PP.W AS PalW,
            PP.H AS PalH,
			-- 修改部分：OriginalFrom字段转换
			CASE 
				WHEN aa.Country = 'CHINA' THEN 'CHN'
				WHEN aa.Country = 'TAIWAN-CHINA' THEN 'TWN'
				ELSE aa.Country 
			END AS OriginalFrom
              --'' AS ROWNUMAA, '' AS ROWNUMAD, '' AS ROWNUMCA, AA.ROWNUMD AS ROWNUMCD
    INTO    #TempSKDSJReport
    FROM    #PP PP
    LEFT JOIN #AA AA ON PP.PalletSN = AA.PalletSN
    LEFT JOIN #CC CC ON AA.MtcPartNo = CC.MtcPartNo
    ORDER BY PP.PalletSN, AA.BoxSN, ItemNoShow;

	UPDATE #TempSKDSJReport
	SET ItemOrder = PalNO + BoxNo + RIGHT('000' + CAST(ItemNoShow AS NVARCHAR(10)),3) + RIGHT('000' + CAST(ItemNo AS  NVARCHAR(10)),3)

    SELECT  *, '纸箱' AS PackageKind, '复合粘胶' AS PalletTexture, '不齐套' AS ISCOMPLETE
    FROM    #TempSKDSJReport --	UNION ALL
--    SELECT  99999 AS ItemNo, '合计' AS ItemNoShow, '' AS CustomerPI, '' AS CustomerCom, '' AS CustomerProd,
--            '' AS MtcComponent, '' AS MtcPartNo, '' AS English, '' AS Specification, '' AS SpecEnglish,
--            '' AS DosageQty, '' AS SinWeight, '' AS TotalQty, '' AS BoxQty, '' AS BoxNum, '' AS BoxNo, '' AS BoxL,
--            '' AS BoxW, '' AS BoxH, '' AS BoxNw, '' AS BoxGw, '' AS PalQty, '' AS PalNum, '' AS PalNo, '' AS PalL,
--            '' AS PalW, '' AS PalH, '' AS TotalNw, '' AS TotalGw, '' AS TotalVol, '' AS Model, '' AS ProdOrderNo,
--            '' AS ProdCode, 'ZZ' AS ItemOrder
            --'' AS ROWNUMAA, '' AS ROWNUMAD, '' AS ROWNUMCA, '' AS ROWNUMCD
	--WHERE BoxNo = 'BJB2024091515-100099'
    ORDER BY ItemOrder, ItemNo;

    RETURN 0;
END;

