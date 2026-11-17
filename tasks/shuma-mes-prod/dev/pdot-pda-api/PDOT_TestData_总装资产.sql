-- =============================================
-- PDOT 联调测试数据（仅总装 MES 测试库）：172.16.9.112 / TV
-- 目的：让 PDA 设备码能经 EquipmentNumber 归一为资产 SN
--   EquipmentNumber      AssetNum
--   10103001185    ->    3001185
--   10103001337    ->    3001337
--   10103001349    ->    3001349
-- 计划：STA1000000TI（TV2025年年终固定资产全面盘点，状态 10）
-- 说明：可重复执行；已存在则整体抛错回滚，不会产生重复数据。
-- 日期：2026-11-17
-- =============================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @StocktakeId CHAR(12) = 'STA1000000TI';
DECLARE @Company VARCHAR(10) = '1000';
DECLARE @FactoryId CHAR(12) = 'FAC10000000L';
DECLARE @ZoneCode VARCHAR(20) = '1#2FDIP/A-A01';

DECLARE @Items TABLE
(
    RowNo           INT PRIMARY KEY,
    AssetNum        NVARCHAR(50),
    EquipmentNumber NVARCHAR(50),
    Descriptionx    NVARCHAR(100),
    Roomer          NVARCHAR(30)
);

INSERT INTO @Items (RowNo, AssetNum, EquipmentNumber, Descriptionx, Roomer)
VALUES
    (1, N'3001185', N'10103001185', N'普太鹰眼智能制造测试系统V3.0', N'刘益闽'),
    (2, N'3001337', N'10103001337', N'普太鹰眼智能制造测试系统V3.0', N'冯秋云'),
    (3, N'3001349', N'10103001349', N'普太鹰眼智能制造测试系统V3.0', N'刘益闽');

IF NOT EXISTS (SELECT 1 FROM dbo.Stocktake WHERE StocktakeId = @StocktakeId)
BEGIN
    THROW 50040, N'盘点计划 STA1000000TI 不存在，已终止', 1;
END

IF EXISTS
(
    SELECT 1
    FROM dbo.AssetDetail a
    INNER JOIN @Items i
        ON a.AssetNum = i.AssetNum OR a.EquipmentNumber = i.EquipmentNumber
)
BEGIN
    THROW 50041, N'测试资产或设备码已存在，已回滚', 1;
END

IF EXISTS
(
    SELECT 1
    FROM dbo.StocktakeCheckList c
    INNER JOIN @Items i ON c.AssetNum = i.AssetNum
    WHERE c.StocktakeId = @StocktakeId
)
BEGIN
    THROW 50042, N'测试计划盘点明细已存在，已回滚', 1;
END

BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @RowNo INT = 1;
    DECLARE @AssetNum NVARCHAR(50);
    DECLARE @EquipmentNumber NVARCHAR(50);
    DECLARE @Descriptionx NVARCHAR(100);
    DECLARE @Roomer NVARCHAR(30);
    DECLARE @AssetDetailId CHAR(12);
    DECLARE @StocktakeCheckListId CHAR(12);

    WHILE @RowNo <= 3
    BEGIN
        SELECT @AssetNum = AssetNum,
               @EquipmentNumber = EquipmentNumber,
               @Descriptionx = Descriptionx,
               @Roomer = Roomer
        FROM @Items
        WHERE RowNo = @RowNo;

        SET @AssetDetailId = '';
        EXEC dbo.SysGetObjectPKId
             @ObjectId = '',
             @ObjectName = N'AssetDetail',
             @PKID = @AssetDetailId OUTPUT;

        INSERT INTO dbo.AssetDetail
        (
            AssetDetailId, FactoryId, AssetHeadId, DivisionId, Company, Activer,
            TypeName, AssetNum, Descriptionx, ExtDescription, UOM, QTY,
            CostCenter, Roomer, IsSoftAsset, Createuser, Createdate,
            ModifyUser, ModifiDate, DeleteFlag, StockTakeId, ZoneCode,
            Operator, RunStauts, NotActiver, NFCCode, EquipmentNumber
        )
        VALUES
        (
            @AssetDetailId, @FactoryId, '', NULL, @Company, 1,
            'M2000', @AssetNum, @Descriptionx, N'PDOT联调测试资产', N'PCS', 1,
            'PDATEST', @Roomer, N'总装接口测试', 'AIAssistant', GETDATE(),
            'AIAssistant', GETDATE(), 0, '', @ZoneCode,
            '', N'正常', 0, NULL, @EquipmentNumber
        );

        SET @StocktakeCheckListId = '';
        EXEC dbo.SysGetObjectPKId
             @ObjectId = '',
             @ObjectName = N'StocktakeCheckList',
             @PKID = @StocktakeCheckListId OUTPUT;

        INSERT INTO dbo.StocktakeCheckList
        (
            StocktakeCheckListId, StocktakeId, AssetDetailid, Company, TypeName,
            AssetNum, EquipmentNumber, Descriptionx, ExtDescription, UOM,
            QTY, CostCenter, IsSoftAsset, Roomer, ZoneCode, NotActiver,
            FirstCheckQTY, FirstCheckOperator, FirstCheckDate,
            ReCheckQTY, ReCheckOperator, ReCheckDate,
            Remark, IsCancel, CreateUserId, CreateDate
        )
        VALUES
        (
            @StocktakeCheckListId, @StocktakeId, @AssetDetailId, @Company, 'M2000',
            @AssetNum, @EquipmentNumber, @Descriptionx, N'PDOT联调测试资产', N'PCS',
            1, 'PDATEST', N'总装接口测试', @Roomer, @ZoneCode, 0,
            0, '', NULL,
            0, '', NULL,
            N'PDOT联调测试数据', 0, 'AIAssistant', GETDATE()
        );

        SET @RowNo = @RowNo + 1;
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH

SELECT a.AssetDetailId,
       a.AssetNum,
       a.EquipmentNumber,
       a.Descriptionx,
       a.Company,
       a.Activer,
       a.IsSoftAsset,
       a.StockTakeId,
       a.ZoneCode,
       c.StocktakeCheckListId,
       c.StocktakeId,
       c.FirstCheckQTY,
       c.ReCheckQTY
FROM dbo.AssetDetail a
INNER JOIN @Items i ON a.AssetNum = i.AssetNum
LEFT JOIN dbo.StocktakeCheckList c
    ON c.StocktakeId = @StocktakeId AND c.AssetNum = a.AssetNum
ORDER BY a.AssetNum;
