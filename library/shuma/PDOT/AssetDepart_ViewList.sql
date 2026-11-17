



-- =============================================
-- Author:		<OBit Team  Jack>
-- Create date: <2009.4.21>
-- Description:	<为获取Bom清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[AssetDepart_ViewList]
    @QueryParameter NVARCHAR(100) = ''
AS
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

     SELECT DISTINCT IsSoftAsset AS DepartName FROM dbo.AssetDetail WHERE Activer = 1
	 RETURN 0

    END;




