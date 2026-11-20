-- =============================================
-- Author:		<OrBit Team benson>
-- Create date: <2016.11.03>
-- Description:	<获取TV 销售订单产品>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[ProductByKD_ViewList]
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键ID
    @I_ParentPKId CHAR(12) = '' ,			--父元对象主键ID
    @QueryParameter NVARCHAR(100) = ''
--以上8个变量为系统服务固定接口参数，必须在每一个ViewWindow过程中实现.>
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT  MO.ProductId, Product.prdname AS ProductName, CONVERT(FLOAT, SUM(MO.MOQtyRequired)) AS SOQty,
		--Customer.CustomerName,
            Product.ProductDescription, MO.SOName
    FROM    MO
    INNER JOIN Product ON MO.ProductId = Product.ProductId
	--AND (left(Product.prdname,2)IN('74','72') or left(pro.ProductName,4)='537Q' OR LEFT(ProductRoot.ProductName,3) = '515' OR LEFT(ProductRoot.ProductName,3) = '539')
    INNER JOIN ProductType ON ProductType.ProductTypeId = Product.ProductTypeId
    LEFT JOIN Customer ON Customer.CustomerId = Product.CustomerId
		--and ( ProductType.ProductTypeName='Z102'or ProductType.ProductTypeName='Z201')
    WHERE   MO.MOTypeId IN ( 'URC1000000Q6', 'URC1000000T5', 'URC1000000T7', 'URC1000000T4', 'URC1000000T2' ) AND MO.ModifyDate >= GETDATE() - 250
    GROUP BY SOName, MO.ProductId, Product.prdname, Product.ProductDescription, Customer.CustomerName
    UNION ALL
    SELECT  b.ProductId, c.prdname AS ProductName, b.SaleQty AS SOQty, c.ProductDescription, a.SOName
    FROM    dbo.SO a
    INNER JOIN dbo.SOItem b ON b.SOId = a.SOId
    INNER JOIN dbo.Product c ON b.ProductId = c.ProductId
    WHERE   a.SOName LIKE '20[5^6]%';

    RETURN 0;

END;

