 
CREATE PROCEDURE [dbo].[SelectPanDianPlan_ViewList] ---得到盘点计划，PanDianOpretor移动事务使用
    @QueryParameter NVARCHAR(100) = ''
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT  StocktakeId, StocktakeDescription, StocktakeName
    FROM    Stocktake
    WHERE   StocktakeStatus  IN ( '10', '20' );

	RETURN 0;

END;


