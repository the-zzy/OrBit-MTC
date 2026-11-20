-- PDOT 网关入口手工测试用例（SQL Server 2016）
-- 仅在确认测试环境后由人工执行；本任务未在数据库执行。
-- 两个过程均固定返回 1 行；returnValue=0 表示业务成功，-1 表示业务失败。

-- 1. 初始化
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTInitQuery
     @Action = 'init',
     @PDOperator = '2061399',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO

-- 2. 查询已盘清单；unchecked 使用相同参数，仅改 queryType。
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTInitQuery
     @Action = 'query',
     @QueryType = 'checked',
     @StocktakeId = 'PD1500008',
     @DepartName = N'生产部',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO

-- 3. 批量资产信息查询；assets 仅 1 条时就是单资产查询。本调用只读，不执行盘点。
-- 预期每条独立返回 success/status/message，未匹配项不影响其他条目。
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTInitQuery
     @Action = 'query',
     @QueryType = 'assets',
     @StocktakeId = 'PD1500008',
     @AssetsJson = N'[{"assetLotSN":"ZC20240001"},{"assetLotSN":"ZC20240002"}]',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO

-- 4. 查询地址清单；不需要 stocktakeId、pdOperator。
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTInitQuery
     @Action = 'query',
     @QueryType = 'location',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO

-- 5. 单条盘点（通过 batchCheck，assets 仅 1 条）。预期 resultsJson 为 1 条明细，unUsedNum 为资产编号。
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTOperate
     @Action = 'batchCheck',
     @StocktakeId = 'PD1500008',
     @PDOperator = '2061399',
     @PDType = N'自盘',
     @ZoneCode = 'A-01-01',
     @AssetsJson = N'[{"assetLotSN":"ZC20240001"}]',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO

-- 6. 批量盘点。预期 total=3，successCount+failCount=3；明细失败不影响其他条目。
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTOperate
     @Action = 'batchCheck',
     @StocktakeId = 'PD1500008',
     @PDOperator = '2061399',
     @PDType = N'自盘',
     @ZoneCode = 'A-01-01',
     @AssetsJson = N'[{"assetLotSN":"ZC20240001"},{"assetLotSN":"ZC20240002"},{"assetLotSN":"ZC20240003"}]',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO

-- 7. 置闲置。
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTOperate
     @Action = 'unused',
     @StocktakeId = 'PD1500008',
     @AssetNum = N'ZC20240001',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO

-- 8. 取消盘点。
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTOperate
     @Action = 'cancel',
     @StocktakeId = 'PD1500008',
     @AssetNum = N'ZC20240001',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO

-- 9. 参数失败仍须返回固定 7/9 列，且 returnValue=-1。
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;
EXEC @ReturnValue = dbo.APIBP_PDOTInitQuery
     @Action = 'query',
     @QueryType = 'checked',
     @StocktakeId = '',
     @ReturnMessage = @ReturnMessage OUTPUT;
SELECT @ReturnValue AS procReturnValue, @ReturnMessage AS outputMessage;
GO
