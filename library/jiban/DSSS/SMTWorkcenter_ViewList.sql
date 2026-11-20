
-- =============================================
-- Author:		<OBit Team  Joey>
-- Create date: <2009.4.21>
-- Description:	<为元字段获取Workcenter清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[SMTWorkcenter_ViewList]
    @QueryParameter NVARCHAR(100) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT  WorkcenterId, WorkcenterName, WorkcenterDescription, a.SiteId, b.SiteName
    FROM    dbo.Workcenter a
    LEFT JOIN dbo.Site b ON a.SiteId = b.SiteId
    WHERE   a.SiteId = 'SIT100000005' AND a.IsActivity = 1
    ORDER BY WorkcenterName;
END;







