-- =============================================
-- Author:		<FZP>
-- Create date: <2025.03.25>
-- Description:	SMT抽检看板数据查询 
-- =============================================
CREATE PROCEDURE [dbo].[SMTInspectionKanBanDataDoMethod]
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
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.
    @StartDate DATETIME = NULL ,
    @EndDate DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	IF ISNULL(@StartDate,'')=''OR ISNULL(@EndDate,'')=''
	BEGIN
		SET @I_ReturnMessage='ServerMessage:开始时间和结束时间不能为空，请检查！'
		RETURN -1
	END

	--DECLARE @StartDate DATETIME=DATEADD(DAY,-1,GETDATE())
	--DECLARE @EndDate DATETIME=GETDATE()

	-- 创建临时表
	DECLARE @TempTable TABLE (
		ProductName NVARCHAR(50),
		SOName NVARCHAR(50),
		MOName NVARCHAR(50),
		WorkcenterName NVARCHAR(50),
		LotQty INT,
		CheckQty INT,
		PassQty INT,
		NGQty INT,
		StoreNumber INT,
		--FinishProportion FLOAT,
		--StoreProportion FLOAT,
		--PassRate FLOAT,
		PersonName NVARCHAR(20),
		RowNum INT 
	);

	INSERT INTO @TempTable
	(
	    ProductName,
	    SOName,
	    MOName,
	    WorkcenterName,
	    LotQty,
	    PersonName,
		StoreNumber
	)
	SELECT DISTINCT c.prdname,a.SOName, a.MOName,d.WorkcenterName,a.LotQty,e.PersonName,b.MOQtyDone
	FROM    dbo.OQACheckDefect a
    LEFT JOIN dbo.MO b ON b.MOName = a.MOName
    LEFT JOIN dbo.Product c ON c.ProductId = b.ProductId
    LEFT JOIN dbo.Workcenter d ON d.WorkcenterId = a.WorkcenterId
	LEFT JOIN dbo.PersonInfo e ON a.Operator = e.PersonNumber
	WHERE   a.Iscancel = 0 AND a.WorkShop ='SMT'
	AND  CAST(a.CreateDate AS DATE) >=@StartDate
	AND  CAST(a.CreateDate AS DATE) <= @EndDate
	AND A.LotQty>200;

	--SELECT * FROM @TempTable

	
	WITH TempTableWithRowNumber AS (
	SELECT ProductName,SOName,MOName,
			ROW_NUMBER() OVER (PARTITION BY MOName, SOName, ProductName ORDER BY (SELECT NULL)) AS RowNum
	FROM @TempTable
	)
	UPDATE t
	SET t.RowNum = r.RowNum
	FROM @TempTable t
	JOIN TempTableWithRowNumber r ON 
	t.MOName = r.MOName 
	AND t.SOName = r.SOName 
	AND t.ProductName = r.ProductName;


	DELETE FROM @TempTable WHERE RowNum<>1


	UPDATE a
	SET a.PassQty = ISNULL(b.OKCount, 0)
	FROM @TempTable a
	LEFT JOIN (
	SELECT MOName, SOName, COUNT(*) AS OKCount
	FROM dbo.OQACheckDefect
	WHERE CheckResult = 'OK'
	GROUP BY MOName, SOName
	) b ON b.MOName = a.MOName AND b.SOName = a.SOName;

	UPDATE a
	SET a.NGQty = ISNULL(b.OKCount, 0)
	FROM @TempTable a
	LEFT JOIN (
	SELECT MOName, SOName, COUNT(*) AS OKCount
	FROM dbo.OQACheckDefect
	WHERE CheckResult = 'NG'
	GROUP BY MOName, SOName
	) b ON b.MOName = a.MOName AND b.SOName = a.SOName;

	UPDATE @TempTable 
	SET CheckQty=CASE 
        WHEN LotQty BETWEEN 2 AND 8 THEN 2
        WHEN LotQty BETWEEN 9 AND 15 THEN 2
        WHEN LotQty BETWEEN 16 AND 25 THEN 3
        WHEN LotQty BETWEEN 26 AND 50 THEN 5
        WHEN LotQty BETWEEN 51 AND 90 THEN 5
        WHEN LotQty BETWEEN 91 AND 150 THEN 8
        WHEN LotQty BETWEEN 151 AND 280 THEN 13
        WHEN LotQty BETWEEN 281 AND 500 THEN 20
        WHEN LotQty BETWEEN 501 AND 1200 THEN 32
        WHEN LotQty BETWEEN 1201 AND 3200 THEN 50
        WHEN LotQty BETWEEN 3201 AND 10000 THEN 80
        WHEN LotQty BETWEEN 10001 AND 35000 THEN 125
        WHEN LotQty BETWEEN 35001 AND 150000 THEN 200
        WHEN LotQty BETWEEN 150001 AND 500000 THEN 315
        WHEN LotQty > 500000 THEN 500
		END


	SELECT 
    ProductName AS '机型',
    SOName AS '订单号',
    MOName AS '工单号',
    WorkcenterName AS '线体',
    LotQty AS '订单数量',
    --StoreNumber AS '入库数',
	CheckQty AS '需检验数',
	PassQty AS 'PASS数',
	NGQty AS 'NG数',

    -- 检验完成比例 = 已检验数 / 需检验数
    CASE 
        WHEN LotQty > 0 AND  FORMAT(CAST(PassQty AS FLOAT) / NULLIF(CAST(CheckQty AS FLOAT), 0) * 100, 'N2') >
			FORMAT(CAST(StoreNumber AS FLOAT) / NULLIF(CAST(LotQty AS FLOAT), 0) * 100, 'N2') 
			THEN FORMAT(CAST(PassQty AS FLOAT) / 
            NULLIF(CAST(CheckQty AS FLOAT), 0) * 100, 'N2') + '%'  -- 转换为百分比并保留两位小数
		--当检验完成比例低于入库比例，将已检验数和检验完成比例标红
		WHEN LotQty > 0 AND  FORMAT(CAST(PassQty AS FLOAT) / NULLIF(CAST(CheckQty AS FLOAT), 0) * 100, 'N2') <
			FORMAT(CAST(StoreNumber AS FLOAT) / NULLIF(CAST(LotQty AS FLOAT), 0) * 100, 'N2')  
			THEN   FORMAT(CAST(PassQty AS FLOAT) / 
            NULLIF(CAST(CheckQty AS FLOAT), 0) * 100, 'N2') + '%' 
        ELSE '0.00%'  -- 如果没有检验数据，返回 0%
    END AS '检验完成比例',


    -- 入库比例 = 入库数 / 订单数量
    --CASE 
    --    WHEN LotQty > 0 THEN FORMAT(CAST(StoreNumber AS FLOAT) / NULLIF(CAST(LotQty AS FLOAT), 0) * 100, 'N2') + '%'
    --    ELSE '0.00%'  -- 如果入库数为零，返回 0%
    --END AS '入库比例',

    -- 检验合格率 = 通过检验数 / 已检验数
    CASE 
        WHEN PassQty > 0 AND PassQty<CheckQty 
		THEN FORMAT(100-CAST(NGQty AS FLOAT) / NULLIF(CAST(CheckQty AS FLOAT), 0) * 100, 'N2') + '%' 
        ELSE '100%'  
    END AS '检验合格率',
	CASE 
	--当检验完成比例低于入库比例，将已检验数和检验完成比例标红和检验数小于需检验数
	WHEN LotQty > 0 AND (CAST(PassQty AS FLOAT) / NULLIF(CAST(CheckQty AS FLOAT), 0) * 100) < 
	(CAST(StoreNumber AS FLOAT) / NULLIF(CAST(LotQty AS FLOAT), 0) * 100)  
	THEN '[检验完成比例:X4Y1]'
	--,[检验合格率:X4Y1]' -- 红色字体

	--当检验完成比例低于入库比例，将已检验数和检验完成比例标红
	WHEN LotQty > 0 
        AND ((CAST(PassQty AS FLOAT) / NULLIF(CAST(CheckQty AS FLOAT), 0) * 100) 
        < (CAST(StoreNumber AS FLOAT) / NULLIF(CAST(LotQty AS FLOAT), 0) * 100))  
	THEN '[检验完成比例:X4Y1]' -- 红色字体
	--检验数小于需检验数
  --  WHEN PassQty > 0 AND PassQty<CheckQty 
		--THEN '[检验合格率:X4Y1]' -- 红色字体
	END AS ColorControlId,
    PersonName AS '检验员'
	INTO #Temptable
	FROM @TempTable
	--WHERE SUBSTRING(ProductName, LEN(ProductName) - 2, 1) <> 'S';
 
	
	-- 使用CTE先获取分组数据，减少重复计算
	;WITH GroupedData AS (
			SELECT 机型, 订单号, 工单号, 订单数量, 需检验数, PASS数, NG数
			FROM #Temptable
			GROUP BY 机型, 订单号, 工单号, 订单数量, 需检验数, PASS数, NG数
	)
	SELECT  机型, 订单号, 工单号, 订单数量, 需检验数, PASS数, NG数,
		STUFF((
			SELECT DISTINCT ', ' + t.[线体]
			FROM #Temptable t
			WHERE t.工单号 = g.工单号 AND t.订单号 = g.订单号
			FOR XML PATH('')
		), 1, 2, '') AS [线体],
		STUFF((
			SELECT DISTINCT ', ' + t.[检验员]
			FROM #Temptable t
			WHERE t.工单号 = g.工单号 AND t.订单号 = g.订单号
			FOR XML PATH('')
		), 1, 2, '') AS [检验员] 
	FROM GroupedData g
	ORDER BY 机型,订单号,工单号;
			 



	DROP TABLE #Temptable

    RETURN 0;
END;



