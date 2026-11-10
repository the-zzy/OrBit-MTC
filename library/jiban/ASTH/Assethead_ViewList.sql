

-- =============================================
-- Author:		<OBit Team  H.R.>
-- Create date: <2008.8.8>
-- Description:	<获取MES单据状态清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[Assethead_ViewList]
    @QueryParameter NVARCHAR(100) = ''
AS
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        SELECT  AssetHeadid,RTRIM(AssetTypeName) AS AssetTypeName  FROM dbo.AssetHead
       
	    RETURN 0
	 
    END;


