
-- =============================================
-- Author:		<OBit Team  Joey>
-- Create date: <2009.4.21>
-- Description:	<为元字段获取Division清单>
-- Rev:1.00
-- =============================================
create PROCEDURE [dbo].[DivisionEquid_ViewListex] 
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@QueryParameter nvarchar(100)=''	--值列表级联时使用
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--SELECT @I_OrBitUserId

	SELECT  DISTINCT   a.DivisionId, a.DivisionName,a.DivisionName AS Original_assets
	FROM         dbo.Division a
	           
	Order by DivisionName
END