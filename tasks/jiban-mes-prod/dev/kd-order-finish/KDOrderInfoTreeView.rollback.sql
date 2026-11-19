-- 恢复基板正式 KDOrderInfoTreeView 到本次改动之前。
-- 接着删除按钮、过程和手工完成表。表里已有的手工标记会一起删掉。

ALTER PROCEDURE [dbo].[KDOrderInfoTreeView]
@I_ReturnMessage nvarchar(max)='' output,
@I_LanguageId char(1)='1',
@I_PlugInCommand varchar(5)='',
@I_FiltCondition	nvarchar(max)='',
@I_OrBitUserId char(12)='',
@I_OrBitUserName nvarchar(100)='',
@I_ResourceId	char(12)='',
@I_ResourceName nvarchar(100)='',
@I_PKId char(12) ='',
@I_ParentPKId char(12)='',
@I_Parameter nvarchar(100)=''
AS
BEGIN
	SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	if @I_PKId<>''
	begin
			SELECT     
			KDOrderInfo.KDOrderInfoId,
			KDOrderInfo.OrderName,
			KDOrderInfo.OrderQty
		FROM        KDOrderInfo
		where KDOrderInfoId=@I_PKId 
		return 0
	end
			
	if @I_PlugInCommand='KDOI'
	begin
		SELECT     
			KDOrderInfo.KDOrderInfoId,
			KDOrderInfo.OrderName,
			KDOrderInfo.OrderQty,OrderDescription,
			case when exists(select 1 from  KDModuleOrder where KDOrderInfoId=KDOrderInfo.KDOrderInfoId) then ''
				else '[RowColor:X4Z]' end ColorControlId
		FROM KDOrderInfo
		where OrderType='1'
		order by KDOrderInfo.CreateDate desc
	end

	if @I_PlugInCommand='KDOIB'
	begin
		SELECT    
			KDOrderInfo.KDOrderInfoId,CASE WHEN IsCancel = 1 THEN '报废单' ELSE '正常' END AS '单据状态', 
			KDOrderInfo.OrderName,
			KDOrderInfo.OrderQty,
			OrderDescription,
			(
				SELECT SUM(IIF(b.PalletSN IS NULL, 1, 0))
				FROM KDPalletInfo a
				LEFT JOIN ShipPallet b ON a.PalletSN = b.PalletSN AND b.IsCancel = 0
				WHERE a.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
				GROUP BY a.KDOrderInfoId
			) AS '栈板未装箱数量'
		FROM        KDOrderInfo
		where OrderType='2'
		AND CreateDate > DATEADD(MONTH, -12, GETDATE())
		order by KDOrderInfo.CreateDate desc
	END
    if @I_PlugInCommand='KDOF'
	begin
		SELECT     
			KDOrderInfo.KDOrderInfoId,
			KDOrderInfo.OrderName,
			KDOrderInfo.OrderQty,OrderDescription
		FROM        KDOrderInfo
		where OrderType='3'
		order by KDOrderInfo.CreateDate desc
	END
	
	IF @I_PlugInCommand = 'KDYN'
	BEGIN
		SELECT     
			KDOrderInfo.KDOrderInfoId,
			KDOrderInfo.OrderName,
			OrderDescription,
			STUFF((
		        SELECT DISTINCT '; ' + MO.SOName 
		        FROM KDMO 
		        INNER JOIN MO ON KDMO.MOId = MO.MOId 
		        WHERE KDMO.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
		        FOR XML PATH('')), 1, 2, '') AS SOName,
		    (
				SELECT SUM(IIF(b.PalletSN IS NULL, 1, 0))
				FROM KDPalletInfo a
				LEFT JOIN ShipPallet b ON a.PalletSN = b.PalletSN AND b.IsCancel = 0
				WHERE a.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
				GROUP BY a.KDOrderInfoId
			) AS '栈板未装箱数量'
		FROM  KDOrderInfo
		where OrderType IN( '9','8','10')
		order by KDOrderInfo.CreateDate desc
	END 

	return 0
END
GO

DELETE FROM dbo.SysMetadataMethod
WHERE MetadataFieldGroupId = 'MFG1000000XJ'
  AND MethodName IN (N'KDOrderFinishChange', N'KDOrderFinishRefresh');

DELETE FROM dbo.SysText
WHERE TextOwner = N'[Public Text]'
  AND TextModule IN (N'KDOrderFinishChange', N'KDOrderFinishRefresh');
GO

IF OBJECT_ID(N'dbo.KDOrderFinishChangeDoMethod', N'P') IS NOT NULL
    DROP PROCEDURE dbo.KDOrderFinishChangeDoMethod;
GO

IF OBJECT_ID(N'dbo.KDOrderFinishRefreshDoMethod', N'P') IS NOT NULL
    DROP PROCEDURE dbo.KDOrderFinishRefreshDoMethod;
GO

IF OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') IS NOT NULL
    DROP TABLE dbo.KDOrderFinishMark;
GO

IF EXISTS (SELECT 1 FROM sys.sequences WHERE name = N'KDOrderFinishMark_PK' AND schema_id = SCHEMA_ID(N'dbo'))
    DROP SEQUENCE dbo.KDOrderFinishMark_PK;
GO

DELETE FROM dbo.SysObject
WHERE ObjectName = N'KDOrderFinishMark';
GO

IF COL_LENGTH(N'dbo.KDOrderInfo', N'IsManualFinish') IS NOT NULL
BEGIN
    ALTER TABLE dbo.KDOrderInfo DROP CONSTRAINT DF_KDOrderInfo_IsManualFinish;
    ALTER TABLE dbo.KDOrderInfo DROP COLUMN IsManualFinish;
END
GO

IF OBJECT_ID(N'dbo.KDOrderLoadedPull', N'P') IS NOT NULL
    DROP PROCEDURE dbo.KDOrderLoadedPull;
GO

IF OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') IS NOT NULL
    DROP TABLE dbo.KDOrderLoadedItem;
GO
