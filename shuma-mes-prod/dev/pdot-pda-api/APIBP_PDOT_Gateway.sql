-- =============================================
-- PDOT 移动盘点 PDA 网关入口存储过程
-- 环境：数码正式环境（shuma-mes-prod）
-- 目标版本：SQL Server 2016
-- 说明：两个入口均只返回一个结果集，成功/失败的列结构固定。
--       集合通过 JSON 字符串字段返回；过程中不使用显式事务。
-- 日期：2026-11-17
-- =============================================

SET NOCOUNT ON;
GO

-- =============================================
-- 1. 初始化 / 清单查询
-- 编排名称：数码_PDOT移动盘点初始化查询
-- =============================================
CREATE PROCEDURE dbo.APIBP_PDOTInitQuery
    @Action         VARCHAR(10),
    @PDOperator     VARCHAR(20) = '',
    @QueryType      VARCHAR(20) = '',
    @StocktakeId    VARCHAR(12) = '',
    @DepartName     NVARCHAR(50) = '',
    @AssetsJson     NVARCHAR(MAX) = N'',
    @ReturnMessage  NVARCHAR(MAX) = '' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperatorName    NVARCHAR(30) = N'';
    DECLARE @PlansJson       NVARCHAR(MAX) = N'[]';
    DECLARE @PDTypesJson     NVARCHAR(MAX) = N'[]';
    DECLARE @DepartmentsJson NVARCHAR(MAX) = N'[]';
    DECLARE @ListJson        NVARCHAR(MAX) = N'[]';
    DECLARE @ErrorMessage    NVARCHAR(4000);
    -- 联调临时开关：1=不校验工号是否在职；恢复校验时改为 0
    DECLARE @SkipOperatorCheck BIT = 1;

    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        SET @Action = LOWER(LTRIM(RTRIM(ISNULL(@Action, ''))));
        SET @QueryType = LOWER(LTRIM(RTRIM(ISNULL(@QueryType, ''))));
        SET @PDOperator = LTRIM(RTRIM(ISNULL(@PDOperator, '')));
        SET @StocktakeId = LTRIM(RTRIM(ISNULL(@StocktakeId, '')));
        SET @DepartName = LTRIM(RTRIM(ISNULL(@DepartName, N'')));

        IF @Action = 'init'
        BEGIN
            IF @SkipOperatorCheck = 0
            BEGIN
                IF @PDOperator = ''
                BEGIN
                    SET @ErrorMessage = N'请输入盘点工号';
                    THROW 50001, @ErrorMessage, 1;
                END

                SELECT @OperatorName = PersonName
                FROM dbo.PersonInfo WITH (NOLOCK)
                WHERE PersonNumber = @PDOperator
                  AND IsActivity = 1;

                IF ISNULL(@OperatorName, N'') = N''
                BEGIN
                    SET @ErrorMessage = N'请输入有效的在职人员';
                    THROW 50002, @ErrorMessage, 1;
                END
            END

            SET @PlansJson = ISNULL((
                SELECT StocktakeId AS stocktakeId,
                       StocktakeDescription AS stocktakeDescription,
                       StocktakeName AS stocktakeName
                FROM dbo.Stocktake WITH (NOLOCK)
                WHERE StocktakeStatus IN ('10', '20')
                ORDER BY StocktakeId
                FOR JSON PATH), N'[]');

            SET @PDTypesJson = ISNULL((
                SELECT PdType AS pdType
                FROM (VALUES (N'自盘'), (N'复盘')) AS t(PdType)
                FOR JSON PATH), N'[]');

            SET @DepartmentsJson = ISNULL((
                SELECT IsSoftAsset AS departName
                FROM dbo.AssetDetail WITH (NOLOCK)
                WHERE Activer = 1
                  AND ISNULL(IsSoftAsset, N'') <> N''
                GROUP BY IsSoftAsset
                ORDER BY IsSoftAsset
                FOR JSON PATH), N'[]');

            SET @ReturnMessage = N'ServerMessage:初始化成功';
            SELECT @OperatorName AS operatorName,
                   @PlansJson AS plansJson,
                   @PDTypesJson AS pdTypesJson,
                   @DepartmentsJson AS departmentsJson,
                   @ListJson AS listJson,
                   @ReturnMessage AS returnMessage,
                   0 AS returnValue;
            RETURN 0;
        END

        IF @Action = 'query'
        BEGIN
            IF @QueryType NOT IN ('checked', 'unchecked', 'location', 'assets', 'operators')
            BEGIN
                SET @ErrorMessage = N'queryType 仅支持 checked、unchecked、location、assets、operators';
                THROW 50003, @ErrorMessage, 1;
            END

            IF @QueryType IN ('checked', 'unchecked', 'assets') AND @StocktakeId = ''
            BEGIN
                SET @ErrorMessage = N'请选择盘点计划';
                THROW 50004, @ErrorMessage, 1;
            END

            IF @QueryType = 'operators'
            BEGIN
                -- 人员下拉：pdOperator 作为搜索词；空搜索返回前 50 人
                SET @ListJson = ISNULL((
                    SELECT TOP 50 p.PersonNumber AS personNumber,
                           p.PersonName AS personName
                    FROM dbo.PersonInfo p WITH (NOLOCK)
                    WHERE p.IsActivity = 1
                      AND (@PDOperator = ''
                           OR p.PersonNumber LIKE @PDOperator + '%'
                           OR p.PersonName LIKE N'%' + @PDOperator + N'%')
                    ORDER BY p.PersonNumber
                    FOR JSON PATH), N'[]');
            END
            ELSE IF @QueryType = 'assets'
            BEGIN
                IF ISJSON(@AssetsJson) <> 1
                BEGIN
                    SET @ErrorMessage = N'assets 必须是 JSON 数组';
                    THROW 50030, @ErrorMessage, 1;
                END

                DECLARE @Requested TABLE
                (
                    RowNo      INT PRIMARY KEY,
                    AssetLotSN NVARCHAR(50),
                    Normalized NVARCHAR(50)
                );

                -- 设备码可能带前导 0；先去掉左侧 0，再参与“公司码+资产编号”归一
                INSERT INTO @Requested (RowNo, AssetLotSN, Normalized)
                SELECT TRY_CAST(j.[key] AS INT) + 1,
                       c.Code,
                       SUBSTRING(c.Code, PATINDEX('%[^0]%', c.Code + N'X'), 50)
                FROM OPENJSON(@AssetsJson) j
                CROSS APPLY (
                    SELECT UPPER(LTRIM(RTRIM(ISNULL(JSON_VALUE(j.value, '$.assetLotSN'), N'')))) AS Code
                ) c;

                IF NOT EXISTS (SELECT 1 FROM @Requested)
                BEGIN
                    SET @ErrorMessage = N'assets 至少包含一条资产条码';
                    THROW 50031, @ErrorMessage, 1;
                END
                IF (SELECT COUNT(*) FROM @Requested) > 100
                BEGIN
                    SET @ErrorMessage = N'assets 单次最多 100 条';
                    THROW 50032, @ErrorMessage, 1;
                END

                DECLARE @QueryFactoryName VARCHAR(100) = '';
                SELECT @QueryFactoryName = f.FactoryName
                FROM dbo.Stocktake s WITH (NOLOCK)
                INNER JOIN dbo.Factory f WITH (NOLOCK) ON f.FactoryId = s.FactoryId
                WHERE s.StocktakeId = @StocktakeId
                  AND s.StocktakeStatus IN ('10', '20');

                IF ISNULL(@QueryFactoryName, '') = ''
                BEGIN
                    SET @ErrorMessage = N'盘点计划不存在或已关闭';
                    THROW 50033, @ErrorMessage, 1;
                END

                SET @ListJson = ISNULL((
                    SELECT ISNULL(a.AssetNum, r.AssetLotSN) AS assetNum,
                           r.AssetLotSN AS assetLotSN,
                           a.Descriptionx AS description,
                           CASE
                               WHEN a.AssetNum IS NULL OR r.AssetLotSN = N'' THEN N'未匹配'
                               WHEN ISNULL(a.StocktakeId, '') = @StocktakeId THEN N'已盘点'
                               ELSE N'未盘点'
                           END AS status,
                           a.Roomer AS roomer,
                           a.IsSoftAsset AS isSoftAsset,
                           a.RunStauts AS runStatus,
                           b.LocationDescription AS location,
                           CAST(NULL AS NVARCHAR(50)) AS locationName,
                           CAST(NULL AS NVARCHAR(100)) AS locationDescription,
                           CAST(CASE WHEN a.AssetNum IS NOT NULL AND r.AssetLotSN <> N'' THEN 1 ELSE 0 END AS BIT) AS success,
                           CASE
                               WHEN r.AssetLotSN = N'' THEN N'资产条码不能为空'
                               WHEN a.AssetNum IS NULL THEN N'找不到有效资产编号[' + r.AssetLotSN + N']'
                               ELSE N''
                           END AS message
                    FROM @Requested r
                    OUTER APPLY (
                        SELECT TOP 1 d.AssetNum, d.Descriptionx, d.StocktakeId, d.Roomer,
                                     d.IsSoftAsset, d.RunStauts, d.ZoneCode
                        FROM dbo.AssetDetail d WITH (NOLOCK)
                        WHERE d.Activer = 1
                          AND d.Company = @QueryFactoryName
                          AND (
                                d.AssetNum = r.AssetLotSN
                             OR d.EquipmentNumber = r.AssetLotSN
                             OR d.AssetNum = r.Normalized
                             OR d.AssetNum = CASE
                                    WHEN r.Normalized LIKE @QueryFactoryName + '%'
                                    THEN SUBSTRING(r.Normalized, LEN(@QueryFactoryName) + 1, 50)
                                END
                          )
                        ORDER BY CASE
                                     WHEN d.AssetNum = r.AssetLotSN THEN 0
                                     WHEN d.EquipmentNumber = r.AssetLotSN THEN 1
                                     WHEN d.AssetNum = r.Normalized THEN 2
                                     ELSE 3
                                 END,
                                 d.AssetNum
                    ) a
                    LEFT JOIN dbo.Location b WITH (NOLOCK) ON b.LocationName = a.ZoneCode
                    ORDER BY r.RowNo
                    FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');
            END
            ELSE IF @QueryType = 'checked'
            BEGIN
                SET @ListJson = ISNULL((
                    SELECT a.AssetNum AS assetNum,
                           a.Descriptionx AS description,
                           N'已盘点' AS status,
                           a.Roomer AS roomer,
                           a.IsSoftAsset AS isSoftAsset,
                           a.RunStauts AS runStatus,
                           b.LocationDescription AS location,
                           CAST(NULL AS NVARCHAR(50)) AS locationName,
                           CAST(NULL AS NVARCHAR(100)) AS locationDescription
                    FROM dbo.AssetDetail a WITH (NOLOCK)
                    LEFT JOIN dbo.Location b WITH (NOLOCK)
                      ON b.LocationName = a.ZoneCode
                    WHERE a.Activer = 1
                      AND ISNULL(a.StocktakeId, '') = @StocktakeId
                      AND (@DepartName = N'' OR a.IsSoftAsset = @DepartName)
                      AND (@PDOperator = '' OR ISNULL(a.Operator, '') = @PDOperator)
                    ORDER BY a.AssetNum
                    FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');
            END
            ELSE IF @QueryType = 'unchecked'
            BEGIN
                SET @ListJson = ISNULL((
                    SELECT a.AssetNum AS assetNum,
                           a.Descriptionx AS description,
                           N'未盘点' AS status,
                           a.Roomer AS roomer,
                           a.IsSoftAsset AS isSoftAsset,
                           a.RunStauts AS runStatus,
                           b.LocationDescription AS location,
                           CAST(NULL AS NVARCHAR(50)) AS locationName,
                           CAST(NULL AS NVARCHAR(100)) AS locationDescription
                    FROM dbo.AssetDetail a WITH (NOLOCK)
                    LEFT JOIN dbo.Location b WITH (NOLOCK)
                      ON b.LocationName = a.ZoneCode
                    WHERE a.Activer = 1
                      AND ISNULL(a.StocktakeId, '') <> @StocktakeId
                      AND (@DepartName = N'' OR a.IsSoftAsset = @DepartName)
                    ORDER BY a.AssetNum
                    FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');
            END
            ELSE
            BEGIN
                SET @ListJson = ISNULL((
                    SELECT CAST(NULL AS NVARCHAR(50)) AS assetNum,
                           CAST(NULL AS NVARCHAR(100)) AS description,
                           CAST(NULL AS NVARCHAR(10)) AS status,
                           CAST(NULL AS NVARCHAR(30)) AS roomer,
                           CAST(NULL AS NVARCHAR(50)) AS isSoftAsset,
                           CAST(NULL AS NVARCHAR(50)) AS runStatus,
                           CAST(NULL AS NVARCHAR(100)) AS location,
                           l.LocationName AS locationName,
                           l.LocationDescription AS locationDescription
                    FROM dbo.Location l WITH (NOLOCK)
                    WHERE l.DivisionId IN ('DIV10000000K', 'DIV10000000P', 'DIV1000000SX')
                    ORDER BY l.LocationName
                    FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');
            END

            SET @ReturnMessage = N'ServerMessage:查询成功';
            SELECT N'' AS operatorName,
                   N'[]' AS plansJson,
                   N'[]' AS pdTypesJson,
                   N'[]' AS departmentsJson,
                   @ListJson AS listJson,
                   @ReturnMessage AS returnMessage,
                   0 AS returnValue;
            RETURN 0;
        END

        SET @ErrorMessage = N'action 仅支持 init、query';
        THROW 50005, @ErrorMessage, 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        IF @ErrNum < 50000
        BEGIN
            INSERT INTO dbo.SqlProcedureIssueLog (
                ProcName, IssueType, StepCode, Message,
                ErrNumber, ErrLine, ErrMessage, OrBitUserId
            )
            VALUES (
                N'APIBP_PDOTInitQuery', N'SQL_EXCEPTION', N'CATCH',
                N'PDOT初始化查询异常', @ErrNum, @ErrLine, @ErrMsg, ''
            );
        END

        SET @ReturnMessage = N'ServerMessage:' + @ErrMsg;
        SELECT N'' AS operatorName,
               N'[]' AS plansJson,
               N'[]' AS pdTypesJson,
               N'[]' AS departmentsJson,
               N'[]' AS listJson,
               @ReturnMessage AS returnMessage,
               -1 AS returnValue;
        RETURN -1;
    END CATCH
END
GO

-- =============================================
-- 2. 批量 / 单条盘点、置闲置、取消盘点
-- 编排名称：数码_PDOT移动盘点操作
-- 说明：batchCheck 同时支持单条和批量，单条时 assets 仅传 1 条
-- =============================================
CREATE PROCEDURE dbo.APIBP_PDOTOperate
    @Action         VARCHAR(20),
    @StocktakeId    VARCHAR(12),
    @PDOperator     VARCHAR(20) = '',
    @PDType         NVARCHAR(2) = N'',
    @ZoneCode       VARCHAR(20) = '',
    @AssetsJson     NVARCHAR(MAX) = N'',
    @AssetNum       NVARCHAR(50) = N'',
    @ReturnMessage  NVARCHAR(MAX) = '' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Description  NVARCHAR(100) = N'';
    DECLARE @Roomer       NVARCHAR(30) = N'';
    DECLARE @UnUsedNum    NVARCHAR(50) = N'';
    DECLARE @ResultsJson  NVARCHAR(MAX) = N'[]';
    DECLARE @Total        INT = 0;
    DECLARE @SuccessCount INT = 0;
    DECLARE @FailCount    INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);
    -- 联调临时开关：1=不校验工号是否在职；恢复校验时改为 0
    DECLARE @SkipOperatorCheck BIT = 1;

    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        SET @Action = LOWER(LTRIM(RTRIM(ISNULL(@Action, ''))));
        SET @StocktakeId = LTRIM(RTRIM(ISNULL(@StocktakeId, '')));
        SET @PDOperator = LTRIM(RTRIM(ISNULL(@PDOperator, '')));
        SET @PDType = LTRIM(RTRIM(ISNULL(@PDType, N'')));
        SET @ZoneCode = UPPER(LTRIM(RTRIM(ISNULL(@ZoneCode, ''))));
        SET @AssetNum = LTRIM(RTRIM(ISNULL(@AssetNum, N'')));

        IF @StocktakeId = ''
        BEGIN
            SET @ErrorMessage = N'盘点计划不能为空';
            THROW 50010, @ErrorMessage, 1;
        END

        IF @Action = 'batchcheck'
        BEGIN
            DECLARE @Pending TABLE
            (
                RowNo       INT IDENTITY(1, 1) PRIMARY KEY,
                AssetLotSN  NVARCHAR(50)
            );

            IF ISJSON(@AssetsJson) <> 1
            BEGIN
                SET @ErrorMessage = N'assets 必须是 JSON 数组';
                THROW 50012, @ErrorMessage, 1;
            END

            INSERT INTO @Pending (AssetLotSN)
            SELECT AssetLotSN
            FROM OPENJSON(@AssetsJson)
            WITH (AssetLotSN NVARCHAR(50) '$.assetLotSN');

            IF NOT EXISTS (SELECT 1 FROM @Pending)
            BEGIN
                SET @ErrorMessage = N'assets 至少包含一条资产条码';
                THROW 50013, @ErrorMessage, 1;
            END
            IF (SELECT COUNT(*) FROM @Pending) > 100
            BEGIN
                SET @ErrorMessage = N'assets 单次最多 100 条';
                THROW 50014, @ErrorMessage, 1;
            END

            IF @SkipOperatorCheck = 0
               AND (@PDOperator = '' OR NOT EXISTS (
                    SELECT 1 FROM dbo.PersonInfo WITH (NOLOCK)
                    WHERE PersonNumber = @PDOperator AND IsActivity = 1))
            BEGIN
                SET @ErrorMessage = N'请输入有效的在职人员';
                THROW 50015, @ErrorMessage, 1;
            END
            IF ISNULL(@PDType, N'') NOT IN (N'自盘', N'复盘')
            BEGIN
                SET @ErrorMessage = N'盘点类型仅支持自盘、复盘';
                THROW 50016, @ErrorMessage, 1;
            END
            IF NOT EXISTS (SELECT 1 FROM dbo.Location WITH (NOLOCK) WHERE LocationName = @ZoneCode)
            BEGIN
                SET @ErrorMessage = N'区域码[' + @ZoneCode + N']在系统中不存在';
                THROW 50017, @ErrorMessage, 1;
            END

            DECLARE @FactoryName VARCHAR(100) = '';
            SELECT @FactoryName = b.FactoryName
            FROM dbo.Stocktake a WITH (NOLOCK)
            INNER JOIN dbo.Factory b WITH (NOLOCK) ON b.FactoryId = a.FactoryId
            WHERE a.StocktakeId = @StocktakeId
              AND a.StocktakeStatus IN ('10', '20');

            IF ISNULL(@FactoryName, '') = ''
            BEGIN
                SET @ErrorMessage = N'盘点计划不存在或已关闭';
                THROW 50018, @ErrorMessage, 1;
            END
            IF NOT EXISTS (SELECT 1
                           FROM dbo.StocktakeCheckList WITH (NOLOCK)
                           WHERE StocktakeId = @StocktakeId
                             AND Company = @FactoryName)
            BEGIN
                SET @ErrorMessage = N'未导入盘点明细表:' + @FactoryName;
                THROW 50019, @ErrorMessage, 1;
            END

            DECLARE @Results TABLE
            (
                RowNo        INT,
                AssetLotSN   NVARCHAR(50),
                Success      BIT,
                Message      NVARCHAR(500),
                Description  NVARCHAR(100),
                Roomer       NVARCHAR(30),
                AssetNum     NVARCHAR(50)
            );

            DECLARE @RowNo             INT;
            DECLARE @CurrentAssetLotSN NVARCHAR(50);
            DECLARE @CurrentAssetNum   NVARCHAR(50);
            DECLARE @ZoneCodeLocal     VARCHAR(20);
            DECLARE @PDOperatorLocal   VARCHAR(20);
            DECLARE @LocationDesc      NVARCHAR(100);
            DECLARE @PKID              CHAR(12);
            DECLARE @OAMessage         NVARCHAR(MAX);

            WHILE EXISTS (SELECT 1 FROM @Pending)
            BEGIN
                SELECT TOP 1 @RowNo = RowNo, @CurrentAssetLotSN = AssetLotSN
                FROM @Pending ORDER BY RowNo;
                DELETE FROM @Pending WHERE RowNo = @RowNo;

                SET @CurrentAssetNum = UPPER(LTRIM(RTRIM(@CurrentAssetLotSN)));
                SET @Description = N'';
                SET @Roomer = N'';
                SET @ZoneCodeLocal = '';
                SET @PDOperatorLocal = '';
                SET @LocationDesc = N'';
                SET @PKID = '';

                BEGIN TRY
                    IF ISNULL(@CurrentAssetNum, N'') = N''
                    BEGIN
                        SET @ErrorMessage = N'资产条码不能为空';
                        THROW 50020, @ErrorMessage, 1;
                    END

                    -- 归一顺序：资产编号 -> 设备编号 -> 去前导 0 -> 公司码+资产编号
                    IF NOT EXISTS (SELECT 1
                                   FROM dbo.AssetDetail WITH (NOLOCK)
                                   WHERE AssetNum = @CurrentAssetNum
                                     AND Activer = 1
                                     AND Company = @FactoryName)
                    BEGIN
                        IF EXISTS (SELECT 1 FROM dbo.AssetDetail WITH (NOLOCK)
                                   WHERE EquipmentNumber = @CurrentAssetNum)
                        BEGIN
                            SELECT TOP 1 @CurrentAssetNum = AssetNum
                            FROM dbo.AssetDetail WITH (NOLOCK)
                            WHERE EquipmentNumber = @CurrentAssetNum;
                        END
                        ELSE
                        BEGIN
                            DECLARE @NormalizedCode NVARCHAR(50);
                            SET @NormalizedCode = SUBSTRING(@CurrentAssetNum,
                                                            PATINDEX('%[^0]%', @CurrentAssetNum + N'X'), 50);

                            IF EXISTS (SELECT 1
                                       FROM dbo.AssetDetail WITH (NOLOCK)
                                       WHERE AssetNum = @NormalizedCode
                                         AND Activer = 1
                                         AND Company = @FactoryName)
                            BEGIN
                                SET @CurrentAssetNum = @NormalizedCode;
                            END
                            ELSE IF @NormalizedCode LIKE @FactoryName + '%'
                                 AND EXISTS (SELECT 1
                                             FROM dbo.AssetDetail WITH (NOLOCK)
                                             WHERE AssetNum = SUBSTRING(@NormalizedCode, LEN(@FactoryName) + 1, 50)
                                               AND Activer = 1
                                               AND Company = @FactoryName)
                            BEGIN
                                SET @CurrentAssetNum = SUBSTRING(@NormalizedCode, LEN(@FactoryName) + 1, 50);
                            END
                        END
                    END

                    IF NOT EXISTS (SELECT 1
                                   FROM dbo.AssetDetail WITH (NOLOCK)
                                   WHERE AssetNum = @CurrentAssetNum
                                     AND Activer = 1
                                     AND Company = @FactoryName)
                    BEGIN
                        SET @ErrorMessage = N'找不到有效资产编号[' + @CurrentAssetNum + N']';
                        THROW 50021, @ErrorMessage, 1;
                    END

                    IF NOT EXISTS (SELECT 1
                                   FROM dbo.StocktakeCheckList WITH (NOLOCK)
                                   WHERE StocktakeId = @StocktakeId
                                     AND AssetNum = @CurrentAssetNum
                                     AND IsCancel = 0)
                    BEGIN
                        EXEC dbo.SysGetObjectPKId
                             @ObjectId = '',
                             @ObjectName = N'StocktakeCheckList',
                             @PKID = @PKID OUTPUT;

                        -- 按需求禁用 OA 消息通知；保留原调用注释，后续如需恢复再评审。
                        -- SET @OAMessage = N'';
                        -- EXEC dbo.SendMsgToOADoMethod
                        --      @I_ReturnMessage = @OAMessage OUTPUT,
                        --      @TriggerProcedure = N'',
                        --      @SendMsg = N'数码盘点执行中APIBP_PDOTOperate',
                        --      @UserName = @PDOperator;

                        INSERT INTO dbo.StocktakeCheckList
                        (
                            StocktakeCheckListId, StocktakeId, AssetDetailid, Company, TypeName,
                            AssetNum, EquipmentNumber, Descriptionx, ExtDescription, UOM,
                            QTY, CostCenter, IsSoftAsset, Roomer, ZoneCode,
                            NotActiver, FirstCheckQTY, FirstCheckOperator, FirstCheckDate, ReCheckQTY,
                            ReCheckOperator, ReCheckDate, Remark, IsCancel, CreateUserId, CreateDate
                        )
                        SELECT @PKID, @StocktakeId, a.AssetDetailId, @FactoryName, N'',
                               @CurrentAssetNum, a.EquipmentNumber, a.Descriptionx, a.ExtDescription, a.UOM,
                               a.QTY, a.CostCenter, a.IsSoftAsset, a.Roomer, a.ZoneCode,
                               a.NotActiver, 0, '', GETDATE(), 0,
                               '', GETDATE(), N'新增配置项', 0, '', GETDATE()
                        FROM dbo.AssetDetail a
                        WHERE a.AssetNum = @CurrentAssetNum
                          AND a.Company = @FactoryName;
                    END

                    IF NOT EXISTS (SELECT 1
                                   FROM dbo.StocktakeCheckList WITH (NOLOCK)
                                   WHERE StocktakeId = @StocktakeId
                                     AND AssetNum = @CurrentAssetNum
                                     AND IsCancel = 0)
                    BEGIN
                        SET @ErrorMessage = N'资产[' + @CurrentAssetNum + N']不在本次盘点计划中';
                        THROW 50022, @ErrorMessage, 1;
                    END

                    SELECT @Description = a.Descriptionx,
                           @Roomer = a.Roomer
                    FROM dbo.AssetDetail a WITH (NOLOCK)
                    WHERE a.AssetNum = @CurrentAssetNum
                      AND a.Company = @FactoryName;

                    IF @PDType = N'自盘'
                    BEGIN
                        IF EXISTS (SELECT 1
                                   FROM dbo.StocktakeCheckList WITH (NOLOCK)
                                   WHERE StocktakeId = @StocktakeId
                                     AND AssetNum = @CurrentAssetNum
                                     AND FirstCheckQTY = 1)
                        BEGIN
                            SELECT @ZoneCodeLocal = ZoneCode,
                                   @PDOperatorLocal = FirstCheckOperator
                            FROM dbo.StocktakeCheckList WITH (NOLOCK)
                            WHERE StocktakeId = @StocktakeId AND AssetNum = @CurrentAssetNum;

                            SELECT @LocationDesc = LocationDescription
                            FROM dbo.Location WITH (NOLOCK)
                            WHERE LocationName = @ZoneCodeLocal;

                            SET @ErrorMessage = N'设备编号[' + @CurrentAssetNum + N']已自盘过，人员['
                                                + @PDOperatorLocal + N']地点[' + ISNULL(@LocationDesc, N'')
                                                + N']，请勿重复盘点';
                            THROW 50023, @ErrorMessage, 1;
                        END
                    END
                    ELSE
                    BEGIN
                        IF EXISTS (SELECT 1
                                   FROM dbo.StocktakeCheckList WITH (NOLOCK)
                                   WHERE StocktakeId = @StocktakeId
                                     AND AssetNum = @CurrentAssetNum
                                     AND ReCheckQTY = 1)
                        BEGIN
                            SELECT @ZoneCodeLocal = ZoneCode,
                                   @PDOperatorLocal = ReCheckOperator
                            FROM dbo.StocktakeCheckList WITH (NOLOCK)
                            WHERE StocktakeId = @StocktakeId AND AssetNum = @CurrentAssetNum;

                            SELECT @LocationDesc = LocationDescription
                            FROM dbo.Location WITH (NOLOCK)
                            WHERE LocationName = @ZoneCodeLocal;

                            SET @ErrorMessage = N'设备编号[' + @CurrentAssetNum + N']已复盘过，人员['
                                                + @PDOperatorLocal + N']地点[' + ISNULL(@LocationDesc, N'')
                                                + N']，请勿重复盘点';
                            THROW 50024, @ErrorMessage, 1;
                        END
                    END

                    UPDATE dbo.StocktakeCheckList
                    SET FirstCheckQTY = IIF(@PDType = N'自盘', 1, FirstCheckQTY),
                        FirstCheckOperator = IIF(@PDType = N'自盘', @PDOperator, FirstCheckOperator),
                        FirstCheckDate = IIF(@PDType = N'自盘', GETDATE(), FirstCheckDate),
                        ReCheckQTY = IIF(@PDType = N'复盘', 1, ReCheckQTY),
                        ReCheckOperator = IIF(@PDType = N'复盘', @PDOperator, ReCheckOperator),
                        ReCheckDate = IIF(@PDType = N'复盘', GETDATE(), ReCheckDate),
                        ZoneCode = @ZoneCode
                    WHERE StocktakeId = @StocktakeId
                      AND AssetNum = @CurrentAssetNum;

                    UPDATE dbo.AssetDetail
                    SET Operator = @PDOperator,
                        StockTakeId = @StocktakeId,
                        NotActiver = 0,
                        stockCheckDate = GETDATE(),
                        ZoneCode = @ZoneCode
                    WHERE AssetNum = @CurrentAssetNum
                      AND Company = @FactoryName;

                    INSERT INTO @Results (RowNo, AssetLotSN, Success, Message, Description, Roomer, AssetNum)
                    VALUES (@RowNo, @CurrentAssetLotSN, 1, N'盘点完成', @Description, @Roomer, @CurrentAssetNum);
                END TRY
                BEGIN CATCH
                    INSERT INTO @Results (RowNo, AssetLotSN, Success, Message, Description, Roomer, AssetNum)
                    VALUES (@RowNo, @CurrentAssetLotSN, 0, ERROR_MESSAGE(), N'', N'', ISNULL(@CurrentAssetNum, N''));
                END CATCH
            END

            SET @ResultsJson = ISNULL((
                SELECT AssetLotSN AS assetLotSN,
                       Success AS success,
                       Message AS message,
                       Description AS description,
                       Roomer AS roomer,
                       AssetNum AS assetNum
                FROM @Results
                ORDER BY RowNo
                FOR JSON PATH), N'[]');

            SELECT @Total = COUNT(*),
                   @SuccessCount = ISNULL(SUM(IIF(Success = 1, 1, 0)), 0),
                   @FailCount = ISNULL(SUM(IIF(Success = 0, 1, 0)), 0)
            FROM @Results;

            -- 单条盘点时兼容原 check 出参；批量时返回汇总消息
            IF @Total = 1
            BEGIN
                SELECT TOP 1 @Description = Description,
                             @Roomer = Roomer,
                             @UnUsedNum = AssetNum
                FROM @Results;

                IF @SuccessCount <> 1
                BEGIN
                    SELECT TOP 1 @ErrorMessage = Message FROM @Results;
                    SET @ReturnMessage = N'ServerMessage:' + ISNULL(@ErrorMessage, N'盘点失败');
                    SELECT N'' AS description,
                           N'' AS roomer,
                           N'' AS unUsedNum,
                           @ResultsJson AS resultsJson,
                           @Total AS total,
                           @SuccessCount AS successCount,
                           @FailCount AS failCount,
                           @ReturnMessage AS returnMessage,
                           -1 AS returnValue;
                    RETURN -1;
                END
                SET @ReturnMessage = N'ServerMessage:盘点完成';
            END
            ELSE
            BEGIN
                SET @ReturnMessage = N'ServerMessage:批量盘点完成：成功 '
                                     + CAST(@SuccessCount AS NVARCHAR(10)) + N' 条，失败 '
                                     + CAST(@FailCount AS NVARCHAR(10)) + N' 条';
            END

            SELECT @Description AS description,
                   @Roomer AS roomer,
                   @UnUsedNum AS unUsedNum,
                   @ResultsJson AS resultsJson,
                   @Total AS total,
                   @SuccessCount AS successCount,
                   @FailCount AS failCount,
                   @ReturnMessage AS returnMessage,
                   0 AS returnValue;
            RETURN 0;
        END

        IF @Action = 'unused'
        BEGIN
            IF @AssetNum = N''
            BEGIN
                SET @ErrorMessage = N'assetNum 不能为空';
                THROW 50025, @ErrorMessage, 1;
            END

            DECLARE @UnusedFactoryName VARCHAR(100) = '';
            SELECT @UnusedFactoryName = b.FactoryName
            FROM dbo.Stocktake a WITH (NOLOCK)
            INNER JOIN dbo.Factory b WITH (NOLOCK) ON b.FactoryId = a.FactoryId
            WHERE a.StocktakeId = @StocktakeId;

            IF ISNULL(@UnusedFactoryName, '') = ''
            BEGIN
                SET @ErrorMessage = N'盘点计划不存在';
                THROW 50026, @ErrorMessage, 1;
            END

            UPDATE dbo.AssetDetail
            SET NotActiver = 1
            WHERE AssetNum = @AssetNum
              AND Company = @UnusedFactoryName;
            IF @@ROWCOUNT = 0
            BEGIN
                SET @ErrorMessage = N'资产不存在或不属于该盘点公司';
                THROW 50027, @ErrorMessage, 1;
            END

            UPDATE b
            SET NotActiver = 1
            FROM dbo.StocktakeCheckList b
            INNER JOIN dbo.Stocktake a ON a.StocktakeId = b.StocktakeId
            WHERE a.StocktakeId = @StocktakeId
              AND b.AssetNum = @AssetNum
              AND b.Company = @UnusedFactoryName;

            SET @ReturnMessage = N'ServerMessage:资产编号[' + @AssetNum + N']已闲置';
            SET @UnUsedNum = @AssetNum;
            SET @Total = 1;
            SET @SuccessCount = 1;

            SELECT N'' AS description,
                   N'' AS roomer,
                   @UnUsedNum AS unUsedNum,
                   N'[]' AS resultsJson,
                   @Total AS total,
                   @SuccessCount AS successCount,
                   @FailCount AS failCount,
                   @ReturnMessage AS returnMessage,
                   0 AS returnValue;
            RETURN 0;
        END

        IF @Action = 'cancel'
        BEGIN
            IF @AssetNum = N''
            BEGIN
                SET @ErrorMessage = N'assetNum 不能为空';
                THROW 50028, @ErrorMessage, 1;
            END

            UPDATE dbo.AssetDetail
            SET StockTakeId = ''
            WHERE Activer = 1
              AND ISNULL(StocktakeId, '') = @StocktakeId
              AND AssetNum = @AssetNum;

            SET @ReturnMessage = N'ServerMessage:取消成功';
            SET @Total = 1;
            SET @SuccessCount = 1;
            SELECT N'' AS description,
                   N'' AS roomer,
                   N'' AS unUsedNum,
                   N'[]' AS resultsJson,
                   @Total AS total,
                   @SuccessCount AS successCount,
                   @FailCount AS failCount,
                   @ReturnMessage AS returnMessage,
                   0 AS returnValue;
            RETURN 0;
        END

        SET @ErrorMessage = N'action 仅支持 batchCheck、unused、cancel';
        THROW 50029, @ErrorMessage, 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        IF @ErrNum < 50000
        BEGIN
            INSERT INTO dbo.SqlProcedureIssueLog (
                ProcName, IssueType, StepCode, Message,
                ErrNumber, ErrLine, ErrMessage, OrBitUserId
            )
            VALUES (
                N'APIBP_PDOTOperate', N'SQL_EXCEPTION', N'CATCH',
                N'PDOT盘点操作异常', @ErrNum, @ErrLine, @ErrMsg, ''
            );
        END

        SET @ReturnMessage = N'ServerMessage:' + @ErrMsg;
        SELECT N'' AS description,
               N'' AS roomer,
               N'' AS unUsedNum,
               N'[]' AS resultsJson,
               0 AS total,
               0 AS successCount,
               0 AS failCount,
               @ReturnMessage AS returnMessage,
               -1 AS returnValue;
        RETURN -1;
    END CATCH
END
GO
