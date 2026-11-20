
-- =============================================
-- Author:		<FZP>
-- Create date: <2025.02.24>
-- Description:	测试直通率看板数据查询
-- =============================================
CREATE PROCEDURE [dbo].[DIPTestRaceKanBanDataDoMethod]
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

	--DECLARE @StartDate DATETIME='2025-03-11 00:00:00'
	--DECLARE @EndDate DATETIME='2025-03-13 00:00:00'

	DECLARE @TempData TABLE
	(
		MOId CHAR(12),
		ProductId CHAR(12),
		SpecificationDes NVARCHAR(20)
	)

	INSERT INTO @TempData
	(
	    MOId,
	    ProductId,
	    SpecificationDes
	)
	 SELECT DISTINCT a.moid,a.ProductId,a.SpecificationDes
	               from dbo.DataChainTEST a  with(nolock)
				   where 1=1 
				 --   AND a.CreateDate >= DATEADD(DAY, -1, GETDATE()) 
					--AND a.CreateDate < GETDATE()  
				    AND a.CreateDate >= @StartDate
					AND a.CreateDate <= @EndDate 
					AND a.SpecificationDes =  RTRIM('DIP 写号') 

	--SELECT * FROM @TempData

	CREATE TABLE #TempFalseTest 
	(
	    Maxid NVARCHAR(12),
	    lotsn NVARCHAR(50),
	    okqty DECIMAL,
	    ttqty DECIMAL,
	    moid NVARCHAR(12),
		MOName NVARCHAR(50),
	    ProductName NVARCHAR(50),
	    ProductDecription NVARCHAR(150),
	    productid NVARCHAR(12),
	    soname NVARCHAR(50),
	    Specification NVARCHAR(30),
	    Ngqty DECIMAL,
		MOQtyDone DECIMAL,
		MOQtyRequired DECIMAL 
	)

    INSERT INTO #TempFalseTest ( lotsn, okqty, ttqty, moid, productid,Specification )
                   Select lotsn,SUM(CASE WHEN a.TestResult IN('0','PASS') THEN 1 ELSE 0 END),
				   COUNT(1),a.moid,a.ProductId,a.SpecificationDes
	               from dbo.DataChainTEST a  with(nolock)
				   INNER JOIN @TempData b ON b.MOId = a.MOId
				   where 1=1 
				 --   AND a.CreateDate >= @StartDate
					--AND a.CreateDate <=@EndDate  
					AND a.SpecificationDes =  RTRIM('DIP 写号') 
				GROUP BY a.lotsn,a.moid,a.ProductId,a.SpecificationDes
	--SELECT * FROM #TempFalseTest

	CREATE INDEX IX_TempFalseTest_ProductID ON #TempFalseTest (productid);

    UPDATE  a
    SET     a.ProductName = b.prdname,
            a.Ngqty = CASE WHEN a.ttqty > ISNULL(a.okqty, 0) AND ISNULL(a.okqty, 0) <> 0 THEN 1
                           ELSE 0
                      END
    FROM    #TempFalseTest a
    INNER  JOIN dbo.Product b WITH ( NOLOCK ) ON b.ProductId = a.productid;	
     
    UPDATE  a
    SET     a.soname = b.SOName,a.MOQtyRequired=b.MOQtyRequired,a.MOQtyDone=b.MOQtyDone,a.MOName=b.MOName
    FROM    #TempFalseTest a
    INNER JOIN dbo.MO b WITH ( NOLOCK ) ON b.MOId = a.moid;	

	--SELECT * FROM #TempFalseTest

     SELECT a.ProductName AS '机型编码', a.soname AS '订单号', a.MOName AS '工单号', a.MOQtyRequired AS '订单数',
		a.MOQtyDone AS '入库数' , COUNT(1) AS '记录数',CAST(SUM(a.Ngqty) AS INT) AS '重测数',
		RTRIM(CONVERT(CHAR, CAST((1 - (SUM(Ngqty) * 1.0 / COUNT(1))) * 100 AS DECIMAL(18,2)))) + '%' AS '直通率',
		RTRIM(CONVERT(CHAR, CAST(COUNT(1) * 1.0 / NULLIF(a.MOQtyRequired, 0) * 100 AS DECIMAL(18,2)))) + '%' AS '测试比例',
		FORMAT(CAST(a.MOQtyDone AS DECIMAL(18, 2)) / CAST(a.MOQtyRequired AS DECIMAL(18, 2)), 'P2') AS '入库比例',
		CASE
		 WHEN (1 - (SUM(Ngqty) * 1.0 / NULLIF(COUNT(1), 0))) * 100 < 90  
		 THEN   '[直通率:X4Y1]' -- 红色字体
		WHEN (COUNT(1) * 1.0 / NULLIF(a.MOQtyRequired, 0) * 100) < 
             (CAST(a.MOQtyDone AS DECIMAL(18, 2)) / NULLIF(CAST(a.MOQtyRequired AS DECIMAL(18, 2)), 0) * 100)
        THEN '[测试比例:X4Y1]' -- 测试比例低于入库比例，标红
		 END AS ColorControlId
        FROM    #TempFalseTest a
        GROUP BY a.ProductName, a.soname,a.MOName,a.MOQtyRequired,a.MOQtyDone;


	

    RETURN 0;
END;












