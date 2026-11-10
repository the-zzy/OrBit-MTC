

-- =============================================

-- Author:		<OrBit Team>

-- Create date: <2008.8.8>

-- Description:	<获取BOMItem的主视图>

-- =============================================

CREATE PROCEDURE [dbo].[BOMItemMainView] 

@I_PKId char(12)=''					--主键

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	

	SELECT  TOP (100) PERCENT 

		dbo.BOMItem.BOMItemId, 

		dbo.SpecificationRoot.SpecificationName AS SpecificationName, 

		[dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, 

		Product.ProductDescription,

		dbo.BOMItem.IsAllowReplace, 

		dbo.BOMItem.IsMESTxn, 

		dbo.BOMItem.QtyRequired,

		dbo.BOMItem.QtyPack,

		dbo.BOMItem.SingleWeight,

		dbo.BOMItem.ReplaceGroup,

		dbo.BOMItem.ReplaceChar,

		dbo.UOM.UOMName,

		dbo.BOMItem.CustomerNumber,

		dbo.BOMItem.ModuleName,

		dbo.BOMItem.EnglishDescription,

		dbo.BOMItem.FieldsA,

		dbo.BOMItem.FieldsB,ProductRoot.ProductWeight

	FROM  dbo.BOMItem 

	INNER JOIN dbo.Product ON dbo.BOMItem.ProductId = dbo.Product.ProductId 

	INNER JOIN dbo.ProductRoot ON dbo.Product.ProductRootId = dbo.ProductRoot.ProductRootId 

	LEFT OUTER JOIN dbo.UOM ON dbo.Product.UsageUOMId = dbo.UOM.UOMId 

	LEFT OUTER JOIN dbo.SpecificationRoot 

	INNER JOIN dbo.Specification ON dbo.SpecificationRoot.SpecificationRootId = dbo.Specification.SpecificationRootId ON 

		dbo.BOMItem.SpecificationId = dbo.Specification.SpecificationId

	WHERE     (dbo.BOMItem.BOMItemId = @I_PKId)

END



























