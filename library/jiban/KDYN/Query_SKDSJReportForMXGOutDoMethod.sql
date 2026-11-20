--**==================================================------
--****************************************************------
--**注意:元对象 Old存储过程将被覆盖，存储过程更新包括 ViewList过程的更新
--****************************************************------
--**==================================================------
--
-- 优化内容：
-- 1. KDOrderInfo 查询与订单头结果输出合并，避免同一订单重复查询。
-- 2. 删除未使用的订单变量。
-- 3. 临时表增加后续关联和排序所需索引。
-- 4. 增加 TRY/CATCH 和异常日志记录。
-- 5. 保留原有参数、返回字段及业务计算逻辑。

CREATE PROCEDURE [dbo].[Query_SKDSJReportForMXGOutDoMethod]
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
    @I_Parameter NVARCHAR(100) = '',
    @StartPalletSn VARCHAR(50) = '',
    @EndPalletSn VARCHAR(50) = ''
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        SET @I_ReturnMessage = '';
        SET @I_ExceptionFieldName = '';

        DECLARE @OrderName NVARCHAR(100);
        DECLARE @KDOrderInfoId CHAR(12);
        DECLARE @CustomerName NVARCHAR(100);
        DECLARE @OrderQty INT;
        DECLARE @ProductCode NVARCHAR(100);
        DECLARE @OrderDate DATETIME;
        DECLARE @Brand NVARCHAR(100);
        DECLARE @Panel NVARCHAR(100);
        DECLARE @SKD NVARCHAR(100);

        IF ISNULL(LTRIM(RTRIM(@I_PKid)), '') = ''
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:请选择订单号!';
            RETURN -1;
        END;

        /*
            订单存在性校验和订单头信息一次完成，避免重复访问 KDOrderInfo。
        */
        SELECT
            @OrderName = T.OrderName,
            @KDOrderInfoId = T.KDOrderInfoId,
            @CustomerName = T.CustomerName,
            @OrderQty = T.OrderQty,
            @ProductCode = T.ProductCode,
            @OrderDate = T.OrderDate,
            @Brand = T.Brand,
            @Panel = T.Panel,
            @SKD = T.SKD
        FROM dbo.KDOrderInfo AS T WITH (NOLOCK)
        WHERE T.KDOrderInfoId = @I_PKid;

        IF ISNULL(@KDOrderInfoId, '') = ''
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:未找到匹配的SKD散件订单信息!';
            RETURN -1;
        END;

        /* 订单基本信息 */
        SELECT
            '' AS BookingNumber,
            '' AS TransCompany,
            '' AS ComAdhBoard,
            '' AS SparePartsFlag,
            CONVERT(NVARCHAR(10), '', 23) AS PlanTime,
            '' AS CabinetNumber,
            '' AS CabinetType,
            ISNULL(CONVERT(NVARCHAR(30), CONVERT(FLOAT, 0)), '') AS PalletWeight,
            '' AS SparePartsNum,
            CONVERT(NVARCHAR(10), '', 23) AS ArrivalTime,
            '' AS SealNumber,
            ISNULL(CONVERT(NVARCHAR(30), CONVERT(FLOAT, 0)), '') AS CabinetWeight,
            '' AS PalletNumber,
            '' AS SparePartsPalNum,
            CONVERT(NVARCHAR(10), '', 23) AS LeftTime,
            REPLACE(@OrderName, 'JB', '') AS OrderNo,
            @CustomerName AS CustomerName,
            '' AS CustomerModelNo,
            CONVERT(NVARCHAR(30), @OrderQty) + 'PCS' AS OrderQty,
            @ProductCode AS ProductsCode,
            CONVERT(NVARCHAR(10), @OrderDate, 23) AS OrderDate,
            '' AS CustomerOrderNo,
            '' AS CustomerPoNo,
            @Brand AS Brand,
            '' AS Area,
            @Panel AS Panel,
            @SKD AS SKD,
            '' AS NoticeNo,
            '' AS SupplierId,
            '' AS SupplierName,
            '' AS BoxMessage,
            '' AS Preparer,
            CONVERT(NVARCHAR(10), '', 23) AS PreparationTime,
            '' AS Checker,
            CONVERT(NVARCHAR(10), '', 23) AS CheckTime,
            '' AS Approver,
            CONVERT(NVARCHAR(10), '', 23) AS ApprovalTime;

        /* 1. 栈板信息 */
        SELECT
            A.PalletSN,
            COUNT(DISTINCT B.BoxSN) AS PalQty,
            1 AS PalNum,
            A.L,
            A.W,
            A.H,
            SUM(ISNULL(C.NetWeight, 0)) AS TotalNw,
            A.PGROSSWEIGHT AS TotalGw
        INTO #PP
        FROM dbo.KDPalletInfo AS A WITH (NOLOCK)
        INNER JOIN dbo.ShipPallet AS B WITH (NOLOCK)
            ON B.PalletSN = A.PalletSN
           AND B.IsCancel = 0
        INNER JOIN dbo.KDBoxInfo AS C WITH (NOLOCK)
            ON C.BoxSN = B.BoxSN
        WHERE A.KDOrderInfoId = @I_PKid
          AND (
                A.PalletSN >= @StartPalletSn
                OR ISNULL(@StartPalletSn, '') = ''
              )
          AND (
                A.PalletSN <= @EndPalletSn
                OR ISNULL(@EndPalletSn, '') = ''
              )
        GROUP BY
            A.PalletSN,
            A.L,
            A.W,
            A.H,
            A.PGROSSWEIGHT
        OPTION (RECOMPILE);

        CREATE CLUSTERED INDEX IX_PP_PalletSN
            ON #PP (PalletSN);

        /* 2. 装箱数据 */
        SELECT
            '' AS MtcComponent,--G.prdname AS MtcComponent,
            B.prdname AS MtcPartNo,
            SUM(H.LotQty) AS BoxQty,
            COUNT(DISTINCT TF.BoxSN) AS BoxNum,
            SUM(H.LotQty) AS ItemQtyRequired,
            P.PalletSN,
            TF.BoxSN,
            MIN(RIGHT(TF.BoxSN, 5)) AS BoxNoMin,
            MAX(RIGHT(TF.BoxSN, 5)) AS BoxNoMax,
            TF.BoxLength AS BoxL,
            TF.BoxWidth AS BoxW,
            TF.BoxHeight AS BoxH,
            SUM(H.LotQty) * ISNULL(MAX(J.UnitNetWeight), 0) / 1000.00 AS BoxNw,
            MAX(TF.GrossWeight) AS BoxGw,
            MAX(E.BOMQtyRequired) BOMQtyRequired,
            MAX(J.UnitNetWeight) AS UnitNetWeight,
            ROW_NUMBER() OVER
            (
                PARTITION BY B.prdname
                ORDER BY
                    LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5),
                    MIN(RIGHT(TF.BoxSN, 5))
            ) AS ROWNUMA,
            ROW_NUMBER() OVER
            (
                PARTITION BY B.prdname
                ORDER BY
                    LEFT(TF.BoxSN, LEN(TF.BoxSN) - 5) DESC,
                    MIN(RIGHT(TF.BoxSN, 5)) DESC
            ) AS ROWNUMD,
            MAX(TF.GrossWeight) AS GrossWeight,
            K.UOMName AS DosageUnit,
            J.Brand,
            J.Country,
            ROW_NUMBER() OVER
            (
                PARTITION BY ISNULL(TF.BoxSN, ''), B.prdname
                ORDER BY P.PalletSN
            ) AS ItemNoShow,
            CAST('' AS NVARCHAR(50)) AS ProdCode,
            CASE
                WHEN MAX(CAST(VD.NoBrand AS INT)) = 1 THEN '-'
                ELSE J.Brand
            END AS NoBrand
        INTO #AA
        FROM dbo.KDBoxItem AS TI WITH (NOLOCK)
        LEFT JOIN dbo.KDBoxInfo AS TF WITH (NOLOCK)
            ON TI.KDBoxInfoId = TF.KDBoxInfoId
        LEFT JOIN dbo.ShipBox AS SP WITH (NOLOCK)
            ON TF.BoxSN = SP.BoxSN
           AND TI.ProductId = SP.ProductId
           AND SP.IsCancel = 0
        LEFT JOIN dbo.ShipPallet AS P WITH (NOLOCK)
            ON P.BoxSN = TF.BoxSN
           AND P.IsCancel = 0
        LEFT JOIN dbo.Product AS B WITH (NOLOCK)
            ON B.ProductId = TI.ProductId
        LEFT JOIN dbo.KDOrderItem AS C WITH (NOLOCK)
            ON TF.KDOrderInfoId = C.KDOrderInfoId
           AND C.ProductId = TI.ProductId
        LEFT JOIN dbo.KDMOItem AS D WITH (NOLOCK)
            ON C.KDOrderItemId = D.KDOrderItemId
        LEFT JOIN dbo.MOItem AS E WITH (NOLOCK)
            ON D.MOItemId = E.MOItemId
        LEFT JOIN dbo.MO AS F WITH (NOLOCK)
            ON E.MOId = F.MOId
        LEFT JOIN dbo.Product AS G WITH (NOLOCK)
            ON F.ProductId = G.ProductId
        LEFT JOIN dbo.KDMOItemLot AS H WITH (NOLOCK)
            ON D.KDMOItemId = H.KDMOItemId
           AND SP.LotSN = H.LotSN
           AND H.IsCancel = 0
        LEFT JOIN dbo.WW_RMInventory AS I WITH (NOLOCK)
            ON SP.LotSN = I.LotSN
        LEFT JOIN dbo.Vendor_Product AS J WITH (NOLOCK)
            ON I.ProductId = J.ProductId
           AND I.VendorId = J.VendorId
        LEFT JOIN dbo.VendorDeliveryItemLot AS VD WITH (NOLOCK)
            ON VD.LotSN = I.LotSN
           AND VD.IsCancel = 0
        LEFT JOIN dbo.UOM AS K WITH (NOLOCK)
            ON K.UOMId = C.UOMId
        WHERE TF.KDOrderInfoId = @KDOrderInfoId  AND (
                p.PalletSN >= @StartPalletSn
                OR ISNULL(@StartPalletSn, '') = ''
              )
          AND (
                p.PalletSN <= @EndPalletSn
                OR ISNULL(@EndPalletSn, '') = ''
              )
          AND TI.IsCancel = 0
          AND TF.BoxNumber NOT LIKE 'SJ/%'
        GROUP BY
            B.prdname,
            --G.prdname,
            --E.BOMQtyRequired,
            P.PalletSN,
            TF.BoxSN,
            TF.BoxLength,
            TF.BoxWidth,
            TF.BoxHeight,
            K.UOMName,
            J.Brand,
            J.Country,
            TF.NetWeight
        HAVING ISNULL(SUM(H.LotQty), 0) > 0;

        CREATE NONCLUSTERED INDEX IX_AA_PalletSN_BoxSN
            ON #AA (PalletSN, BoxSN)
            INCLUDE
            (
                MtcPartNo,
                BoxQty,
                ItemQtyRequired,
                UnitNetWeight
            );

        UPDATE #AA
        SET Brand = NoBrand;

        /* 3. 物料描述 */
        SELECT
            C.prdname AS MtcPartNo,
            C.EngDesc,
            C.ProductDescription
        INTO #CC
        FROM dbo.KDOrderItem AS TK WITH (NOLOCK)
        LEFT JOIN dbo.Product AS C WITH (NOLOCK)
            ON C.ProductId = TK.ProductId
        WHERE TK.KDOrderInfoId = @KDOrderInfoId;

        CREATE NONCLUSTERED INDEX IX_CC_MtcPartNo
            ON #CC (MtcPartNo);

        /* 4. 生成报表明细 */
        SELECT
            ROW_NUMBER() OVER
            (
                ORDER BY PP.PalletSN, AA.BoxSN, AA.ItemNoShow
            ) AS ItemNo,
            AA.ItemNoShow,
            '' AS CustomerPI,
            '' AS CustomerCom,
            'K' + AA.MtcPartNo AS CustomerProd,
            ISNULL(AA.MtcComponent, '') AS MtcComponent,
            AA.MtcPartNo,
            CC.EngDesc AS SpecEnglish,
            CASE
                WHEN AA.DosageUnit = 'ML' THEN 'L'
                ELSE AA.DosageUnit
            END AS DosageUnit,
            AA.Brand,
            CC.ProductDescription AS Specification,
            '' AS English,
            CASE
                WHEN AA.DosageUnit = 'ML'
                    THEN CAST(AA.BOMQtyRequired / 1000.0 AS FLOAT)
                ELSE CAST(AA.BOMQtyRequired AS FLOAT)
            END AS DosageQty,
            FORMAT(AA.UnitNetWeight / 1000, '0.0000000') AS SinWeight,
            CASE
                WHEN AA.DosageUnit = 'ML'
                    THEN CAST(AA.ItemQtyRequired / 1000.0 AS FLOAT)
                ELSE CAST(AA.ItemQtyRequired AS FLOAT)
            END AS TotalQty,
            CASE
                WHEN AA.DosageUnit = 'ML'
                    THEN CAST(AA.BoxQty / 1000.0 AS FLOAT)
                ELSE CAST(AA.BoxQty AS FLOAT)
            END AS BoxQty,
            CAST(AA.BoxNum AS FLOAT) AS BoxNum,
            AA.BoxSN AS BoxNo,
            CAST(AA.BoxL AS FLOAT) AS BoxL,
            CAST(AA.BoxW AS FLOAT) AS BoxW,
            CAST(AA.BoxH AS FLOAT) AS BoxH,
            CAST(AA.BoxNw AS DECIMAL(18, 5)) AS BoxNw,
            CAST(AA.BoxGw AS DECIMAL(18, 5)) AS BoxGw,
            CAST(AA.BoxNw AS DECIMAL(18, 5)) AS TotalNw,
            FORMAT(
                CAST(STR(PP.TotalGw, 10, 5) AS DECIMAL(18, 5)),
                '0.#####'
            ) AS TotalGw,
            CAST(
                CAST(PP.L AS DECIMAL(18, 5))
                * CAST(PP.W AS DECIMAL(18, 5))
                * CAST(PP.H AS DECIMAL(18, 5))
                / 1000000000.0
                AS DECIMAL(18, 5)
            ) AS TotalVol,
            '' AS Model,
			''  AS ProdOrderNo, '' AS ProdCode,
            CAST('' AS NVARCHAR(200)) AS ItemOrder,
            CASE
                WHEN AA.DosageUnit = 'ML'
                    THEN CAST(AA.BoxQty / 1000.0 AS FLOAT)
                ELSE CAST(AA.BoxQty AS FLOAT)
            END AS PalQty,
            PP.PalNum,
            PP.PalletSN AS PalNO,
            PP.L AS PalL,
            PP.W AS PalW,
            PP.H AS PalH,
            CASE
                WHEN AA.Country = 'CHINA' THEN 'CHN'
                WHEN AA.Country = 'TAIWAN-CHINA' THEN 'TWN'
                ELSE AA.Country
            END AS OriginalFrom
        INTO #TempSKDSJReport
        FROM #PP AS PP
        LEFT JOIN #AA AS AA
            ON PP.PalletSN = AA.PalletSN
        LEFT JOIN #CC AS CC
            ON AA.MtcPartNo = CC.MtcPartNo;

        UPDATE #TempSKDSJReport
        SET ItemOrder =
            PalNO
            + BoxNo
            + RIGHT('000' + CAST(ItemNoShow AS NVARCHAR(10)), 3)
            + RIGHT('000' + CAST(ItemNo AS NVARCHAR(10)), 3)
			--, MtcComponent='';

        CREATE CLUSTERED INDEX IX_TempSKDSJReport_ItemOrder
            ON #TempSKDSJReport (ItemOrder, ItemNo);

        SELECT
            T.*,
            '纸箱' AS PackageKind,
            '复合粘胶' AS PalletTexture,
            '不齐套' AS ISCOMPLETE
        FROM #TempSKDSJReport AS T
        ORDER BY
            T.ItemOrder,
            T.ItemNo;

        SET @I_ReturnMessage = N'ServerMessage:操作成功';
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        INSERT INTO dbo.SqlProcedureIssueLog
        (
            ProcName,
            IssueType,
            StepCode,
            Message,
            ErrNumber,
            ErrLine,
            ErrMessage,
            OrBitUserId
        )
        VALUES
        (
            N'Query_SKDSJReportForMXGOutDoMethod',
            N'SQL_EXCEPTION',
            N'CATCH',
            N'SKD散件订单汇出异常',
            @ErrNum,
            @ErrLine,
            @ErrMsg,
            @I_OrBitUserId
        );

        SET @I_ReturnMessage = N'ServerMessage:' + @ErrMsg;
        RETURN -1;
    END CATCH;
END;
