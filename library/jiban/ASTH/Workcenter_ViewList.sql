
-- =============================================
-- Author:		<OBit Team  Joey>
-- Create date: <2009.4.21>
-- Description:	<为元字段获取Workcenter清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[Workcenter_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT     WorkcenterId, WorkcenterName,WorkcenterDescription,a.Siteid,b.SiteName,a.WorkcenterName AS Location
	FROM         dbo.Workcenter a left join dbo.site b on a.SiteId=b.SiteId
	Order by WorkcenterName
END

