-- =============================================
-- Author:		<LZH>
-- Create date: <2024.06.01>
-- Description:	SKD装箱标签打印
-- =============================================
CREATE PROCEDURE [dbo].[Txn_SKDBoxLabelPrintDoMethod]
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
    @I_Parameter NVARCHAR(100) = ',' ,		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    --@BoxSN VARCHAR(50) = '',
    @NewStartBoxSN VARCHAR(50) = '',
    @NewEndBoxSN VARCHAR(50) = '',
    @BoxLabelName NVARCHAR(100) = '',
    @BoxSN VARCHAR(50) = '',
    @Password VARCHAR(50) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
   
    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @SOName VARCHAR(20);
    DECLARE @BatchNO VARCHAR(50);
	DECLARE @BoxNumber VARCHAR(50);
	DECLARE @CustomerField1 NVARCHAR(500);
   
    -- 声明表变量
	DECLARE @BoxInfo TABLE (
		BoxSN VARCHAR(50),
	    OrderName VARCHAR(50),
	    OrderQty INT,
	    CustomerName VARCHAR(50),
	    CustomerModel VARCHAR(50),
	    BatchNO VARCHAR(50),
	    CartonNO VARCHAR(50),
	    BoxNumber VARCHAR(50),
	    ProductName VARCHAR(50),
	    BoxQty INT,
	    BoxDesc VARCHAR(50),
	    SparePart VARCHAR(50),
	    BoxLength INT,
	    BoxWidth INT,
	    BoxHeight INT,
	    NetWeight NUMERIC(10, 2),
	    GrossWeight NUMERIC(10, 2),
	    CustomerField1 VARCHAR(500),
	    CustomerField2 VARCHAR(500),
	    CustomerField3 VARCHAR(500),
	    CustomerField4 VARCHAR(500)
	);

	IF ISNULL(@BoxSN, '') <> ''
	BEGIN
		SET @NewStartBoxSN = @BoxSN;
		SET @NewEndBoxSN = @BoxSN;
	
		SELECT @KDOrderInfoId = KDOrderInfoId, @I_ParentPKId = KDBoxInfoId FROM KDBoxInfo WHERE BoxSN = @BoxSN;
	END 

   
    IF ISNULL(@NewStartBoxSN,'') = '' OR ISNULL(@NewEndBoxSN,'') = ''
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage:起始箱号和截止箱号不能为空，请检查！'
		RETURN -1				
	END;
	
	SELECT @KDOrderInfoId = b.KDOrderInfoId, @SOName = b.SOName  
	FROM dbo.KDBoxInfo a
	INNER JOIN dbo.KDOrderInfo b ON a.KDOrderInfoId = b.KDOrderInfoId
	WHERE KDBoxInfoId = @I_ParentPKId;

	SELECT @BatchNO = BatchNum FROM MO WHERE SOName = @SOName AND ISNULL(BatchNum, '') <> '';

	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.KDBoxInfo WHERE KDOrderInfoId = @KDOrderInfoId AND BoxSN = @NewStartBoxSN )
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage:起始箱号不存在！'
		RETURN -1;
	END;

	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.KDBoxInfo WHERE KDOrderInfoId = @KDOrderInfoId AND BoxSN = @NewEndBoxSN )
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage:截止箱号不存在！'
		RETURN -1;
	END;

	IF @NewStartBoxSN > @NewEndBoxSN
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage:起始箱号不能大于截止箱号！'
		RETURN -1;
	END
	
	IF EXISTS (
		SELECT 1 
		FROM KDBoxInfo
		WHERE KDOrderInfoId = @KDOrderInfoId 
		AND BoxSN >= @NewStartBoxSN 
		AND BoxSN <= @NewEndBoxSN 
		AND IsCancel = 0
		AND ISNULL(PrintCount, 0) > 0
	) AND ISNULL(@Password, '') <> 'KDOIB2024'
	AND (RIGHT(@NewStartBoxSN, 4) <> '0001' OR RIGHT(@NewEndBoxSN, 4) <> '0001')
	AND @I_PlugInCommand NOT IN ('SKDBF')
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage:该箱号已经打印过，请输入密码！'
		RETURN -1;
	END 
   
	
    INSERT INTO @BoxInfo (
    	BoxSN,
	    OrderName, 
	    OrderQty, 
	    CustomerName, 
	    CustomerModel, 
	    BatchNO, 
	    CartonNO, 
	    ProductName, 
	    BoxQty, 
	    BoxDesc, 
	    SparePart, 
	    BoxLength, 
	    BoxWidth, 
	    BoxHeight, 
	    NetWeight, 
	    GrossWeight,
	    CustomerField1,
	    CustomerField2,
	    CustomerField3,
	    CustomerField4
	)
	SELECT 
		a.BoxSN,
	    b.SOName AS OrderName, 
	    b.OrderQty, 
	    b.CustomerName,
	    b.CustomerModel, 
	    @BatchNO,
	    a.BoxNumber AS CartonNO, 
	    d.prdname AS ProductName,
	    c.RealQty AS BoxQty,
	    NULL AS BoxDesc, 
	    NULL AS SparePart,
	    a.BoxLength AS BoxLength, 
	    a.BoxWidth AS BoxWidth, 
	    a.BoxHeight AS BoxHeight, 
	    a.NetWeight, 
	    a.GrossWeight,
	    b.CustomerField1,
	    b.CustomerField2,
	    b.CustomerField3,
	    b.CustomerField4
	FROM KDBoxInfo a WITH (NOLOCK)
	INNER JOIN KDOrderInfo b WITH (NOLOCK) ON a.KDOrderInfoId = b.KDOrderInfoId
	INNER JOIN KDBoxItem c WITH (NOLOCK) ON a.KDBoxInfoId = c.KDBoxInfoId
	INNER JOIN Product d WITH (NOLOCK) ON c.ProductId = d.ProductId
	WHERE b.KDOrderInfoId = @KDOrderInfoId 
	AND a.BoxSN >= @NewStartBoxSN 
	AND a.BoxSN <= @NewEndBoxSN 
	AND a.IsCancel = 0
	ORDER BY a.BoxSN;

	UPDATE KDBoxInfo 
	SET PrintCount = PrintCount + 1, IsPrint = 1 
	WHERE KDOrderInfoId = @KDOrderInfoId 
	AND BoxSN >= @NewStartBoxSN 
	AND BoxSN <= @NewEndBoxSN 
	AND IsCancel = 0;



	UPDATE @BoxInfo 
	SET 
		BoxDesc = CASE WHEN LEFT(ProductName, 3) IN ('515') THEN 'Main board ass''y'
    			       WHEN LEFT(ProductName, 3) IN ('514') THEN 'power board'
    			   	   ELSE '' END,    
    	CartonNO = dbo.ConvertStrToClumn(CartonNO, '/', 1) + FORMAT(CAST(dbo.ConvertStrToClumn(CartonNO, '/', 2) AS INT), '000'),				
		BoxNumber = dbo.ConvertStrToClumn(CartonNO, '/', 2);
	
	UPDATE @BoxInfo 
	SET CustomerField1 = REPLACE(CustomerField1, '{订单号}', OrderName), 
		CustomerField2 = REPLACE(CustomerField2, '{订单号}', OrderName),
	 	CustomerField3 = REPLACE(CustomerField3, '{订单号}', OrderName),
	 	CustomerField4 = REPLACE(CustomerField4, '{订单号}', OrderName);
	 
	UPDATE @BoxInfo 
	SET CustomerField1 = REPLACE(CustomerField1, '{料号}', ProductName), 
		CustomerField2 = REPLACE(CustomerField2, '{料号}', ProductName),
	 	CustomerField3 = REPLACE(CustomerField3, '{料号}', ProductName),
	 	CustomerField4 = REPLACE(CustomerField4, '{料号}', ProductName)
	 
	UPDATE @BoxInfo 
	SET CustomerField1 = REPLACE(CustomerField1, '{订单数量}', OrderQty), 
		CustomerField2 = REPLACE(CustomerField2, '{订单数量}', OrderQty),
	 	CustomerField3 = REPLACE(CustomerField3, '{订单数量}', OrderQty),
	 	CustomerField4 = REPLACE(CustomerField4, '{订单数量}', OrderQty);

	UPDATE @BoxInfo 
	SET CustomerField1 = REPLACE(CustomerField1, '{每箱数量}', BoxQty), 
		CustomerField2 = REPLACE(CustomerField2, '{每箱数量}', BoxQty),
	 	CustomerField3 = REPLACE(CustomerField3, '{每箱数量}', BoxQty),
	 	CustomerField4 = REPLACE(CustomerField4, '{每箱数量}', BoxQty);
   
	UPDATE @BoxInfo 
	SET CustomerField1 = REPLACE(CustomerField1, '{外箱编号数字}', BoxNumber),
		CustomerField2 = REPLACE(CustomerField2, '{外箱编号数字}', BoxNumber),
		CustomerField3 = REPLACE(CustomerField3, '{外箱编号数字}', BoxNumber),
		CustomerField4 = REPLACE(CustomerField4, '{外箱编号数字}', BoxNumber);
	
	--add by lzh 2025-02-12 临时修改订单号
	UPDATE @BoxInfo SET OrderName = '2130006928' WHERE OrderName IN ('2130006793', '2130006794');
   

   	SELECT BoxSN AS '箱号',
   		   OrderName AS '订单号',
   		   OrderQty AS '订单数量',
   		   CustomerName AS '客户名称',
   		   CustomerModel AS '客户型号',
   		   BatchNO AS '批次号',
   		   CartonNO AS '外箱编号',
   		   BoxNumber AS '外箱编号数字',
   		   ProductName AS '料号',
   		   ProductName AS '料号2',
   		   BoxQty AS '每箱数量',
   		   BoxDesc AS '描述',
   		   SparePart AS '类型',
   		   BoxLength AS '长',
   		   BoxWidth AS '宽',
   		   BoxHeight AS '高',
   		   NetWeight AS '净重',
   		   GrossWeight AS '毛重',
   		   FORMAT(GETDATE(), 'yyyy-MM-dd') AS '日期',
   		   CustomerField1 AS '自定义1',
   		   CustomerField2 AS '自定义2',
   		   CustomerField3 AS '自定义3',
   		   CustomerField4 AS '自定义4'
    FROM @BoxInfo;
   		  
    SET @I_ReturnMessage = 'ServerMessage: 获取箱号数据成功，开始打印!';
   
    RETURN 0;
END;













