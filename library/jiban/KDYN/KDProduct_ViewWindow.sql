

-- =============================================
-- Author:		<OBit Team  H.R.>
-- Create date: <2008.8.8>
-- Description:	<为元字段获取Product清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[KDProduct_ViewWindow] 
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12)='',				--主键ID
@I_ParentPKId char(12)='',			--父元对象主键ID
@QueryParameter nvarchar(100)=''
--以上8个变量为系统服务固定接口参数，必须在每一个ViewWindow过程中实现.>
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT TOP (100) PERCENT 
		Product.ProductId ,
		Product.UsageUOMId as UOMId,
		[dbo].[RemoveZero](ProductRoot.ProductName) as ProductName,
		UOM.UOMName,
		Product.ProductDescription
	FROM  Product 
	INNER JOIN ProductRoot ON Product.ProductRootId = ProductRoot.ProductRootId
	left join UOM on Product.UsageUOMId=UOM.UOMId
	where Product.IsKD=1
	ORDER BY ProductName

	return 0

END


