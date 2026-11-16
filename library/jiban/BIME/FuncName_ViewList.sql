
-- =============================================
-- Author:		<Wang AL>
-- Create date: <2021.01.13>
-- Description:	<AMPM>
-- Rev:1.00
-- =============================================
CREATE  PROCEDURE [dbo].[FuncName_ViewList]
    @QueryParameter NVARCHAR(100) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT  'SMT排产数据' AS FuncName, 'SMT_SRTA_ProductSchedule' AS TableName
    UNION ALL
    SELECT  'SMT库存数据' AS FuncName, 'SMT_SRTA_MaterialStock' AS TableName
    UNION ALL
    SELECT  'SMT在途库存' AS FuncName, 'SMT_SRTA_OpenStock' AS TableName
    UNION ALL
    SELECT  'SMT BOM清单' AS FuncName, 'SMT_SRTA_BOMList' AS TableName
    UNION ALL
    SELECT  '小米整机BOM导入' AS FuncName, 'PACKAGING' AS TableName
    UNION ALL
    SELECT  '小米裸机BOM导入' AS FuncName, 'FA' AS TableName
    UNION ALL
    SELECT  '小米M阶BOM导入' AS FuncName, 'DIP' AS TableName
    UNION ALL
    SELECT  '小米J阶BOM导入' AS FuncName, 'SMT' AS TableName
	UNION ALL
    SELECT  '损耗报工' AS FuncName, 'FeedBack' AS TableName
	UNION ALL
    SELECT  'CKD客户料号' AS FuncName, 'CustomerMateriel' AS TableName
    UNION ALL
    SELECT  'SKD数据预置(料号-机型)' AS FuncName, 'KDOrderInfo' AS TableName
    UNION ALL
    SELECT  'SKD数据预置(料号)' AS FuncName, 'KDOrderInfo' AS TableName
    UNION ALL
    SELECT  'SKD数据预置(标签-料号)' AS FuncName, 'KDOrderInfo' AS TableName;
   
    RETURN 0;
END;










