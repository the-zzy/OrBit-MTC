
-- =============================================
-- Author:		<Orbit Team Phoenix>
-- Create date: <2021.08.03>
-- Description:	SKD散件订单汇出
-- =============================================
CREATE PROCEDURE [dbo].[Query_SKDSJReportOutDoMethod]
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
    @I_Parameter NVARCHAR(100) = ''		--插件参数

 --以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
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

    DECLARE @TempKDOrderInfoId TABLE ( KDOrderInfoId CHAR(12) );
	
    IF ISNULL(@I_PKid, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择订单号!';
        RETURN -1;
    END;

    SELECT  @KDOrderName = OrderName, @KDOrderInfoId = KDOrderInfoId
    FROM    dbo.KDOrderInfo
    WHERE   KDOrderInfoId = @I_PKid;

    IF ISNULL(@KDOrderInfoId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:未找到匹配的SKD散件订单信息!';
        RETURN -1;
    END;

    IF ISNULL(@KDOrderInfoId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:未找到匹配的KD散件订单信息!';
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

    SELECT  b.prdname AS ProductName, b.ProductDescription, TS.*, b.prdname AS ModuleSN, c.UOMName AS DosageUnit,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY TS.KDOrderItemId ) AS ROWNUMA,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY TS.KDOrderItemId DESC ) AS ROWNUMD
    INTO    #AA
    FROM    dbo.KDOrderItem TS
    LEFT JOIN dbo.Product b ON b.ProductId = TS.ProductId
    LEFT JOIN dbo.UOM c ON c.UOMId = TS.UOMId
    WHERE   TS.KDOrderInfoId = @KDOrderInfoId;

    SELECT  c.prdname AS ModuleSN, TK.*
    INTO    #BB
    FROM    KDOrderItem TK
    LEFT JOIN dbo.Product c ON c.ProductId = TK.ProductId
    INNER JOIN @TempKDOrderInfoId b ON b.KDOrderInfoId = TK.KDOrderInfoId;

    SELECT  b.prdname AS ModuleSN, TI.RealQty AS BoxQty, COUNT(DISTINCT TF.BoxSN) AS BoxNum,
            LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5) AS BoxSN, MIN(RIGHT(TF.BoxSN, 5)) AS BoxNoMin,
            MAX(RIGHT(TF.BoxSN, 5)) AS BoxNoMax, TF.BoxLength AS BoxL, TF.BoxWidth AS BoxW, TF.BoxHeight AS BoxH,
            MAX(TF.NetWeight) AS BoxNw, MAX(TF.GrossWeight) AS BoxGw,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5), MIN(RIGHT(TF.BoxSN, 5)) )
            AS ROWNUMA,
            ROW_NUMBER() OVER ( PARTITION BY b.prdname ORDER BY LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5) DESC, MIN(RIGHT(TF.BoxSN,
                                                                                                        5)) DESC ) AS ROWNUMD,
            MAX(GrossWeight) AS GrossWeight
    INTO    #CC
    FROM    KDBoxItem TI
    LEFT JOIN KDBoxInfo TF ON TI.KDBoxInfoId = TF.KDBoxInfoId
    LEFT JOIN dbo.Product b ON b.ProductId = TI.ProductId
    WHERE   TF.KDOrderInfoId = @KDOrderInfoId AND TI.RealQty > 0 AND TF.BoxNumber NOT LIKE 'SJ/%'
    GROUP BY b.prdname, TI.RealQty, LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5), TF.BoxLength, TF.BoxWidth, TF.BoxHeight;

    SELECT  '' AS ItemNo, '' AS ItemNoShow, '' AS CustomerPI, '' AS CustomerCom, '' AS CustomerProd,
            AA.ModuleName AS MtcComponent, AA.ProductName AS MtcPartNo, AA.EnglishDescription AS English,
            AA.ProductDescription AS Specification, AA.EnglishDescription AS SpecEnglish,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, AA.BOMQtyRequired)), '') AS DosageQty,
            CAST(CAST(CC.BoxNw / CC.BoxQty AS DECIMAL(18, 2)) AS NVARCHAR(20)) AS SinWeight,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, AA.ItemQtyRequired)), '') AS TotalQty,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, CC.BoxQty)), '') AS BoxQty,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, CC.BoxNum)), '') AS BoxNum,
            ( CASE WHEN CC.BoxNum = 1 THEN ISNULL(CONVERT(NVARCHAR, CC.BoxSN + CC.BoxNoMin), '')
                   ELSE ISNULL(CONVERT(NVARCHAR, CC.BoxSN + CC.BoxNoMin + '-' + CC.BoxNoMax), '')
              END ) AS BoxNo, ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, CC.BoxL)), '') AS BoxL,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, CC.BoxW)), '') AS BoxW,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, CC.BoxH)), '') AS BoxH,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, CC.BoxNw)), '') AS BoxNw,
            ISNULL(CONVERT(NVARCHAR, CONVERT(FLOAT, CC.BoxGw)), '') AS BoxGw, '' AS PalQty, '' AS PalNum, '' AS PalNo,
            '' AS PalL, '' AS PalW, '' AS PalH, '' AS TotalNw, '' AS TotalGw, '' AS TotalVol, '' AS Model,
            '' AS ProdOrderNo, '' AS ProdCode, AA.DosageUnit,
            ( CASE WHEN CC.BoxSN IS NULL OR CC.BoxSN = '' THEN 'ZY'-- + CONVERT(NVARCHAR, AA.ItemNo + 10000)
                   ELSE CC.BoxSN + CC.BoxNoMin + '-' + CC.BoxNoMax --+ CONVERT(NVARCHAR, AA.ItemNo + 10000)
              END ) AS ItemOrder, AA.ROWNUMA AS ROWNUMAA, AA.ROWNUMD AS ROWNUMAD, CC.ROWNUMA AS ROWNUMCA,
            CC.ROWNUMD AS ROWNUMCD
    INTO    #TempSKDSJReport
    FROM    #AA AA
    LEFT JOIN #BB BB ON AA.ModuleSN = BB.ModuleSN
    LEFT JOIN #CC CC ON CC.ModuleSN = AA.ModuleSN AND (
                                                        AA.ROWNUMA + AA.ROWNUMD = 2 OR CC.ROWNUMA + CC.ROWNUMD = 2 OR ( AA.ROWNUMA + AA.ROWNUMD < CC.ROWNUMA + CC.ROWNUMD ) OR (
                                                                                                        AA.ROWNUMA + AA.ROWNUMD >= CC.ROWNUMA + CC.ROWNUMD AND FLOOR(( AA.ROWNUMA - 1 ) / CEILING(CONVERT(FLOAT, ( AA.ROWNUMA + AA.ROWNUMD - 1 )) / CONVERT(FLOAT, ( CC.ROWNUMA + CC.ROWNUMD - 1 )))) + 1 = CC.ROWNUMA
                                                                                                        )
                                                      );
	SELECT  ItemNo, ItemNoShow, CustomerPI, CustomerCom, CustomerProd, MtcComponent, MtcPartNo, English, Specification,
            SpecEnglish, DosageQty, SinWeight, TotalQty, BoxQty, BoxNum, BoxNo, BoxL, BoxW, BoxH, BoxNw, BoxGw, PalQty,
            PalNum, PalNo, PalL, PalW, PalH, TotalNw, TotalGw, TotalVol, Model, ProdOrderNo, ProdCode, DosageUnit,
            '纸箱' AS PackageKind, '复合粘胶' AS PalletTexture, '不齐套' AS ISCOMPLETE,'中国' AS OriginalFrom, ItemOrder, ROWNUMAA, ROWNUMAD, ROWNUMCA,
            ROWNUMCD
    FROM    #TempSKDSJReport
    UNION ALL
    SELECT  99999 AS ItemNo, '合计' AS ItemNoShow, '' AS CustomerPI, '' AS CustomerCom, '' AS CustomerProd,
            '' AS MtcComponent, '' AS MtcPartNo, '' AS English, '' AS Specification, '' AS SpecEnglish, '' AS DosageQty,
            '' AS SinWeight, '' AS TotalQty, '' AS BoxQty, '' AS BoxNum, '' AS BoxNo, '' AS BoxL, '' AS BoxW, '' AS BoxH,
            '' AS BoxNw, '' AS BoxGw, '' AS PalQty, '' AS PalNum, '' AS PalNo, '' AS PalL, '' AS PalW, '' AS PalH,
            '' AS TotalNw, '' AS TotalGw, '' AS TotalVol, '' AS Model, '' AS ProdOrderNo, '' AS ProdCode,
            '' AS DosageUnit, '' AS PackageKind, '' AS PalletTexture, '' AS ISCOMPLETE,'' AS OriginalFrom, 'ZZ' AS ItemOrder,
            '' AS ROWNUMAA, '' AS ROWNUMAD, '' AS ROWNUMCA, '' AS ROWNUMCD
    ORDER BY ItemOrder, ItemNo;

    RETURN 0;
END;



