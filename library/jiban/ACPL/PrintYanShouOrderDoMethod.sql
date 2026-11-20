 
 
 
CREATE PROCEDURE  [dbo].[PrintYanShouOrderDoMethod]  ---打印设备验收单
 
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_IsNewRow bit = 0 output,				--向客户端报告是否是新行
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12) = '',				--主键事务
@I_SourcePKId char(12)='',			--执行拷贝时传入的源主键  
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)=''			--插件参数
 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
 
SELECT   AcceptanceList.AcceptanceListNO,
  Product.ProductDescription AS EquipmentName, Product.ProductDescription_1 AS EquipmentType, AcceptanceList.InstallationLocation, CONVERT(NVARCHAR(10), 
                AcceptanceList.InstallationDate, 120) AS InstallationDate, AcceptanceList.Recipient, AcceptanceList.ContactPhone, 
                AcceptanceList.Situation1, AcceptanceList.Situation2, AcceptanceList.Situation3, AcceptanceList.Situation4, 
                AcceptanceList.Orther
FROM      ProductRoot INNER JOIN
                Product ON ProductRoot.ProductRootId = Product.ProductRootId INNER JOIN
                AcceptanceList ON Product.ProductId = AcceptanceList.AcceptanceEquipentId  WHERE  AcceptanceListid=@I_PKId
  RETURN 0
END

















