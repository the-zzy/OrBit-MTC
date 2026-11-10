-- =============================================

-- Author:		<OrBit Team：Joey>

-- Create date: <2009.4.20>

-- Description:	<获取Factory的主视图>

-- =============================================

CREATE PROCEDURE [dbo].[FactoryMainView] 

@I_PKId char(12)=''					--主键>

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED



	SELECT     

		dbo.Factory.FactoryId,

		dbo.Factory.FactoryName,

		dbo.Factory.IsActivity,

		dbo.Factory.FactoryCode, 

		dbo.Factory.FactoryDescription, 

		dbo.Enterprise.EnterpriseId, 

		dbo.Enterprise.EnterpriseName

	FROM         dbo.Factory 

	LEFT OUTER JOIN dbo.Enterprise ON dbo.Factory.EnterpriseId = dbo.Enterprise.EnterpriseId

	WHERE     (FactoryId = @I_PKId)

END

