-- =============================================
-- Author:		<David>
-- Create date: <2022.04.02>
-- Description:	组装装箱打印
-- =============================================
CREATE PROCEDURE dbo.Txn_LEDHalfBoxScanPrintLabel
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='', 		--插件参数
@TBoxSN NVARCHAR(50)=''				--外箱
as
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	SET NOCOUNT ON;

	IF ISNULL(@TBoxSN,'')<>''
	BEGIN
	    DECLARE @Level nVARCHAR(50)=''
		DECLARE @FLType CHAR(10)=''
		SELECT @FLType=FLType FROM dbo.ShipBox WHERE BoxSN=@TBoxSN


		
		--IF @FLType IN ('01','06')
		--BEGIN
			SELECT DISTINCT '箱体' AS TypeModel,
						convert(NVARCHAR(10),getdate(),120)AS CreateDate,
						RIGHT(MOName,10)AS MOName,
						prdname AS ProductName,
						'' AS Customer,
						CAST(SUM(Qty)AS INT) AS Qty,
						''AS Series,
						ZXINGHAO,
						BoxSN,
						 '良品'  AS BoxType
			FROM dbo.ShipBox
			INNER JOIN dbo.MO ON MO.MOId = ShipBox.MOId
			INNER JOIN dbo.Product ON Product.ProductId = ShipBox.ProductId
			INNER JOIN dbo.ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
			LEFT JOIN dbo.SO ON SO.SOName = MO.SOName
			LEFT JOIN dbo.Customer ON Customer.CustomerId = so.CustomerId
			--LEFT JOIN  dbo.Sa_WPC_ExtendItem ON   Class='BoxScanType'AND Remark01=FLType
			WHERE BoxSN=@TBoxSN AND IsCancel=0
			GROUP BY FLType,CustomerAbbr,ZXINGHAO,BoxSN,MOName,prdname
		--END
		

		SET @I_ReturnMessage='ServerMessage:箱号【'+@TBoxSN+'】打印成功'
		RETURN 0

	END



end


