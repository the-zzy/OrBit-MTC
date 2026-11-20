
-- =============================================
-- Author:		<FZP>
-- Create date: <2025.02.24>
-- Description:	维修数据看板查询
-- =============================================
CREATE PROCEDURE [dbo].[DIPMaintenanceKanBanDataDoMethod]
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

    DECLARE @TempDefectRate TABLE
        (
          Createdate DATE ,
          MOId CHAR(12) DEFAULT '' ,
          WorkcenterId CHAR(12) DEFAULT '' ,
          DefectCode NVARCHAR(50) DEFAULT '' ,
          Qty INT DEFAULT 0 ,
          DefectRate DECIMAL(18, 2) DEFAULT 0
        );
	
    DECLARE @TempDCRepairRecord TABLE
        (
          CreateDate datetime ,
          LotSN NVARCHAR(50) DEFAULT '' ,
          MOId CHAR(12) DEFAULT '' ,
          WorkcenterId CHAR(12) DEFAULT '' ,
          DefectCode NVARCHAR(50) DEFAULT '' ,
          DefectSpecificationId CHAR(12) DEFAULT '' ,
          DefectDescription NVARCHAR(200) DEFAULT '' ,
          DefectLocation NVARCHAR(50) DEFAULT '' ,
          DefectReason NVARCHAR(50) DEFAULT '' ,
          ReCheckDescription NVARCHAR(50) DEFAULT '' ,
          DcfectProductname NVARCHAR(30) DEFAULT '' ,
          PrdDesCription NVARCHAR(200) DEFAULT '' ,
          RepairMethod NVARCHAR(100) DEFAULT '' ,
          DefectResponsibility NVARCHAR(50) DEFAULT '' ,
          RepairUser NVARCHAR(50) DEFAULT '' ,
          ProductId CHAR(12) DEFAULT '' ,
		  DefectDataId CHAR(12) DEFAULT ''
        );

	DECLARE @TempMOId TABLE
	(
		MOId CHAR(12) DEFAULT ''
	)


	INSERT  INTO @TempDCRepairRecord ( CreateDate, LotSN, MOId, WorkcenterId, DefectCode, DefectSpecificationId,
								DefectDescription, DefectLocation, DefectReason, ReCheckDescription,
								DcfectProductname, PrdDesCription, RepairMethod, DefectResponsibility, RepairUser,
								ProductId, DefectDataId )
	SELECT  a.CreateDate  AS CreateDate, a.LotSN, a.MOId, a.WorkcenterId, a.DefectCode,
			a.DefectSpecificationId, a.DefectDescription, a.DefectLocation, a.DefectReason, a.ReCheckDescription,
			a.DcfectProductname, a.PrdDesCription, a.RepairMethod, a.DefectResponsibility, a.RepairUser,
			a.ProductId, a.DefectDataId
	FROM    dbo.DCRepairRecord a
	LEFT JOIN dbo.MO b ON b.MOId = a.MOId
	WHERE   1 = 1
	AND a.CreateDate >= @StartDate
	AND a.CreateDate < @EndDate


    INSERT  INTO @TempMOId ( MOId )
            SELECT DISTINCT
                    MOId
            FROM    @TempDCRepairRecord;

    INSERT  INTO @TempDefectRate ( Createdate, MOId, WorkcenterId, DefectCode, Qty, DefectRate )
            SELECT  CAST(a.CreateDate AS DATE) AS Createdate, a.MOId, a.WorkcenterId, a.DefectCode,
                    COUNT(DISTINCT a.LotId) AS Qty,
                    CAST(COUNT(DISTINCT a.LotId) * 100.0 / b.MOQtyRequired AS DECIMAL(18, 2)) AS DefectRate
            FROM    @TempMOId z 
			INNER JOIN dbo.DCRepairRecord a ON a.MOId = z.MOId
            LEFT JOIN dbo.MO b ON b.MOId = a.MOId
            WHERE   a.DefectSpecificationId IN ( 'SPE1000001A5', 'SPE10000019F', 'SPE10000019G', 'SPE10000019M',
                                                 'SPE1000001AF' )
            GROUP BY CAST(a.CreateDate AS DATE), a.MOId, a.WorkcenterId, a.DefectCode, b.MOQtyRequired;

	DECLARE @specification TABLE
	(
	SpecificationId CHAR(20)
	)

	INSERT INTO @specification
	(
	    SpecificationId
	)
    SELECT DISTINCT
            a.SpecificationId
    FROM    dbo.WorkflowStep a
    INNER JOIN dbo.WorkflowRoot b ON b.DefaultWorkflowId = a.WorkflowId
    WHERE   b.WorkflowName LIKE '%基板%' AND ISNULL(a.SpecificationId, '') <> '';


	DECLARE @TempData TABLE
	(
	  SOName NVARCHAR(50), 
	  MOName NVARCHAR(50), 
	  MOQtyRequired NVARCHAR(50), 
	  LotSN NVARCHAR(50),
	  ProductName NVARCHAR(50), 
	  DefectDescription NVARCHAR(150),  
	  DefectLocation NVARCHAR(50),
	  DcfectProductname NVARCHAR(50)
	)

	INSERT INTO @TempData
	(
	    SOName,
	    MOName,
	    MOQtyRequired,
	    LotSN,
	    ProductName,
	    DefectLocation,
	    DcfectProductname,
		DefectDescription
	)
    SELECT   c.SOName, RIGHT(c.MOName, 10) AS MoName, c.MOQtyRequired, a.LotSN,
            e.ProductName,  a.DefectLocation,a.DcfectProductname,a.DefectDescription
    FROM    @TempDCRepairRecord a
    INNER JOIN @specification q ON q.SpecificationId = a.DefectSpecificationId
    LEFT JOIN dbo.DCUpLineScan x ON a.LotSN = x.LotSN
    LEFT JOIN MO c ON a.MOId = c.MOId AND a.ProductId = c.ProductId
    LEFT JOIN Product d ON a.ProductId = d.ProductId
    LEFT JOIN ProductRoot e ON d.ProductId = e.DefaultProductId
	LEFT JOIN @TempDefectRate h ON h.Createdate = a.CreateDate AND h.MOId = a.MOId AND h.WorkcenterId = a.WorkcenterId AND h.DefectCode = a.DefectCode
	WHERE c.MOQtyRequired>200  --只获取订单数大于200的工单
	AND LEFT(RIGHT(e.ProductName, 3), 1) <> 'S'  --去除SMT的料号

	--SELECT * FROM  @TempData

	DECLARE @ResuletData TABLE
	(
	  SOName NVARCHAR(50), 
	  MOName NVARCHAR(50), 
	  MOQtyRequired NVARCHAR(50), 
	  DefectQty NVARCHAR(50),
	  ProductName NVARCHAR(50),
	  DefectDescription NVARCHAR(150),  
	  DefectLocation NVARCHAR(150)
	)

	INSERT INTO @ResuletData
	(
	    SOName,
	    MOName,
	    MOQtyRequired,
		ProductName
	)
	SELECT DISTINCT  
		SOName,
	    MOName,
	    MOQtyRequired,
		ProductName
	FROM @TempData

	UPDATE a
	SET a.DefectQty = b.DefectCount
	FROM @ResuletData a
	INNER JOIN (
	SELECT SOName, MOName, COUNT(*) AS DefectCount
	FROM @TempData
	GROUP BY SOName, MOName
	) b
	ON a.SOName = b.SOName
	AND a.MOName = b.MOName;


	--删除良品率小于0.65%的数据
	DELETE FROM @ResuletData 
	WHERE CAST(DefectQty AS DECIMAL(18, 2)) / CAST(MOQtyRequired AS DECIMAL(18, 2))<0.0065
	OR SOName='' OR SOName IS NULL OR MOName='' OR MOName IS NULL

		-- 创建临时表
	DECLARE @DefectData TABLE(
		SOName NVARCHAR(50),
		MOName NVARCHAR(50),
		DefectDescription NVARCHAR(150),
		DefectNumber NVARCHAR(20),
		RowNum INT
	);

	-- 插入数据到临时表 #DefectData
	INSERT INTO @DefectData (SOName, MOName, DefectDescription, DefectNumber, RowNum)
	SELECT 
		a.SOName,
		a.MOName,
		a.DefectDescription,
		COUNT(a.DefectDescription) AS DefectNumber,
		ROW_NUMBER() OVER (PARTITION BY a.SOName, a.MOName ORDER BY COUNT(a.DefectDescription) DESC, a.DefectDescription) AS RowNum
	FROM @TempData a
	INNER JOIN @ResuletData r ON a.SOName = r.SOName AND a.MOName = r.MOName
	GROUP BY a.SOName, a.MOName, a.DefectDescription;

	-- 查询临时表的数据
	--SELECT * FROM @DefectData;

	UPDATE a SET a.DefectDescription=b.DefectDescription +'('+b.DefectNumber+')'
	FROM  @ResuletData a
	INNER JOIN @DefectData b ON b.MOName = a.MOName AND b.SOName = a.SOName
	WHERE RowNum=1

	UPDATE a SET a.DefectDescription=a.DefectDescription+'/'+b.DefectDescription +'('+b.DefectNumber+')'
	FROM  @ResuletData a
	INNER JOIN @DefectData b ON b.MOName = a.MOName AND b.SOName = a.SOName
	WHERE RowNum=2

	UPDATE a SET a.DefectDescription=a.DefectDescription+'/'+b.DefectDescription +'('+b.DefectNumber+')'
	FROM  @ResuletData a
	INNER JOIN @DefectData b ON b.MOName = a.MOName AND b.SOName = a.SOName
	WHERE RowNum=3



	DECLARE @DefectLocalData TABLE(
	SOName NVARCHAR(50),
	MOName NVARCHAR(50),
	DefectLocal NVARCHAR(150),
	DefectLocationNumber NVARCHAR(20),
	RowNum INT
	);

	INSERT INTO @DefectLocalData
	(
	    SOName,
	    MOName,
	    DefectLocal,
	    DefectLocationNumber,
	    RowNum
	)
	SELECT 
    a.SOName,
    a.MOName,
	a.DefectLocation,
	COUNT(a.DefectLocation),
	ROW_NUMBER() OVER (PARTITION BY a.SOName, a.MOName ORDER BY a.DefectLocation) AS RowNum
	FROM @TempData a
	INNER JOIN @ResuletData r ON a.SOName = r.SOName AND a.MOName = r.MOName
	GROUP BY a.SOName, a.MOName, a.DefectLocation
	ORDER BY  a.SOName,a.MOName,RowNum

	UPDATE a SET a.DefectLocation=b.DefectLocal +'('+b.DefectLocationNumber+')'
	FROM  @ResuletData a
	INNER JOIN @DefectLocalData b ON b.MOName = a.MOName AND b.SOName = a.SOName
	WHERE RowNum=1

	UPDATE a SET a.DefectLocation=a.DefectLocation+'/'+b.DefectLocal +'('+b.DefectLocationNumber+')'
	FROM  @ResuletData a
	INNER JOIN @DefectLocalData b ON b.MOName = a.MOName AND b.SOName = a.SOName
	WHERE RowNum=2

	UPDATE a SET a.DefectLocation=a.DefectLocation+'/'+b.DefectLocal +'('+b.DefectLocationNumber+')'
	FROM  @ResuletData a
	INNER JOIN @DefectLocalData b ON b.MOName = a.MOName AND b.SOName = a.SOName
	WHERE RowNum=3

	SELECT ProductName AS '机型编码',SOName AS '订单号',
	MOName AS '工单号',MOQtyRequired AS '订单数',
	DefectQty AS '不良数', FORMAT(CAST(DefectQty AS DECIMAL(18, 2)) / CAST(MOQtyRequired AS DECIMAL(18, 2)), 'P2') AS '不良率',
	DefectDescription AS 'TOP3不良现象及数量',DefectLocation AS 'TOP3不良位号',
	CASE WHEN CAST(DefectQty AS DECIMAL(18, 2)) / CAST(MOQtyRequired AS DECIMAL(18, 2)) >0.01 	
	THEN '[不良率:X4Y1]' -- 红色字体
		END AS ColorControlId
	FROM @ResuletData
	WHERE DefectQty>5    

	

    RETURN 0;
END;












