









-- =============================================

-- Author:		<OrBit Team>

-- Create date: <2008.8.8>

-- Description:	<获取BOM主显示字段>

-- =============================================

CREATE PROCEDURE [dbo].[BOMMainView] 

@I_PKId char(12)=''					--主键

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED



	SELECT     

		dbo.BOMRoot.BOMRootId, 

		[dbo].[RemoveZero](BOMRoot.BOMName) as BOMName, 

		dbo.BOM.BOMRevision, 

		Factory.FactoryName,

		dbo.BOM.BOMDescription, 

		dbo.BOM.IsActivity, 

		dbo.BOM.IsDefaultBOM,

		dbo.BOM.ERPDate,

		dbo.BOM.ModifyDate

	FROM         dbo.BOM 

	INNER JOIN dbo.BOMRoot ON dbo.BOM.BOMRootId = dbo.BOMRoot.BOMRootId

	left join Factory on Factory.FactoryId=BOM.FactoryId

	WHERE     (dbo.BOM.BOMId = @I_PKId)



END











