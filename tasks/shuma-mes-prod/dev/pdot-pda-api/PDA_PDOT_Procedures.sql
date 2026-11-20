-- =============================================
-- PDOT 移动盘点 PDA 接口后台存储过程草稿
-- 环境：数码正式环境（shuma-mes-prod），SQL Server 2016
-- 说明：保持原有 PDA_PanDianScanOpreatorDoMethod / PDA_GetPanDianRefListDoMethod 业务逻辑
--       对外 2 个接口，后台也仅 2 个存储过程，通过 @Action 分支处理
--       遵循 .AGENTS/rules/stored-procedure-rules.md：
--       1. 存储过程内部禁止显式事务，由外层调用方控制
--       2. 必须使用 TRY/CATCH，异常写入 SqlProcedureIssueLog
--       3. 统一返回值：成功 RETURN 0，失败 RETURN -1
--       4. 返回消息带 ServerMessage: 前缀
--       5. 避免游标，优先集合操作；查询使用 WITH(NOLOCK)
-- 批量盘点：在 PDA_PDOT_Operate 内部通过表值参数 + 集合操作完成，避免 API 层循环调用
-- 日期：2026-11-17
-- =============================================

SET NOCOUNT ON;
GO

-- =============================================
-- 0. 用户定义表类型：批量盘点资产列表
-- =============================================
IF TYPE_ID(N'dbo.PDOTAssetList') IS NULL
BEGIN
    CREATE TYPE dbo.PDOTAssetList AS TABLE
    (
        AssetLotSN NVARCHAR(30) NOT NULL PRIMARY KEY
    );
END
GO

-- =============================================
-- 1. 初始化 / 查询
--    对应接口：init-query
--    @Action = init  ：人员校验 + 基础数据查询
--    @Action = query ：已盘 / 未盘 / 地址清单查询
-- =============================================
CREATE PROCEDURE dbo.PDA_PDOT_InitQuery
    @I_ReturnMessage      NVARCHAR(MAX) = '' OUTPUT,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,
    @I_LanguageId         CHAR(1) = '1',
    @I_PlugInCommand      VARCHAR(5) = '',
    @I_OrBitUserId        CHAR(12) = '',
    @I_OrBitUserName      NVARCHAR(100) = '',
    @I_ResourceId         CHAR(12) = '',
    @I_ResourceName       NVARCHAR(100) = '',
    @I_PKid               CHAR(12) = '',
    @I_ParentPKId         CHAR(12) = '',
    @Action               VARCHAR(20) = '',     -- init / query
    @QueryType            VARCHAR(20) = '',     -- checked / unchecked / location
    @StocktakeId          VARCHAR(12) = '',
    @PDOperator           VARCHAR(20) = '',
    @DepartName           NVARCHAR(50) = ''
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        SET @I_ReturnMessage = '';
        SET @I_ExceptionFieldName = '';

        -- =============================================
        -- 1.1 初始化
        -- =============================================
        IF @Action = 'init'
        BEGIN
            DECLARE @PersonInfoId VARCHAR(12) = '';
            DECLARE @PersonName   NVARCHAR(30) = '';

            -- 校验盘点工号是否在职
            SELECT  @PersonInfoId = PersonInfoId,
                    @PersonName   = PersonName
            FROM    dbo.PersonInfo WITH(NOLOCK)
            WHERE   PersonNumber = @PDOperator
              AND   IsActivity = 1;

            IF ISNULL(@PersonInfoId, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage: 请输入有效的在职人员!';
                SET @I_ExceptionFieldName = 'PDOperator';
                RETURN -1;
            END

            -- 返回人员信息
            SELECT  @PDOperator AS PDOperator,
                    @PersonName AS OperatorName;

            -- 返回盘点计划（状态 10/20）
            SELECT  StocktakeId,
                    StocktakeDescription,
                    StocktakeName
            FROM    dbo.Stocktake WITH(NOLOCK)
            WHERE   StocktakeStatus IN ('10', '20');

            -- 返回盘点类型
            SELECT N'自盘' AS Pdtype
            UNION ALL
            SELECT N'复盘' AS Pdtype;

            -- 返回部门列表（原 AssetDepart_ViewList 逻辑）
            SELECT DISTINCT
                    IsSoftAsset AS DepartName
            FROM    dbo.AssetDetail WITH(NOLOCK)
            WHERE   Activer = 1
              AND   ISNULL(IsSoftAsset, '') <> '';

            SET @I_ReturnMessage = N'ServerMessage: 初始化成功';
            RETURN 0;
        END

        -- =============================================
        -- 1.2 查询清单
        -- =============================================
        IF @Action = 'query'
        BEGIN
            IF @QueryType = 'location'
            BEGIN
                DECLARE @DivisionId VARCHAR(12) = '';

                SELECT  @DivisionId = DivisionId
                FROM    dbo.SysUser WITH(NOLOCK)
                WHERE   UserId = @I_OrBitUserId;

                IF @DivisionId = 'DIV10000000P'
                    SET @DivisionId = 'DIV1000000SX';

                SELECT  LocationName,
                        LocationDescription
                FROM    dbo.Location WITH(NOLOCK)
                WHERE   DivisionId IN ('DIV10000000K', 'DIV10000000P', 'DIV1000000SX');

                RETURN 0;
            END

            IF ISNULL(@StocktakeId, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage: 请退回主画面选择盘点计划表';
                SET @I_ExceptionFieldName = 'StocktakeDescription';
                RETURN -1;
            END

            IF @QueryType = 'unchecked'
            BEGIN
                SELECT  ROW_NUMBER() OVER (ORDER BY GETDATE()) AS Init,
                        AssetNum,
                        Descriptionx,
                        N'未盘点' AS Status,
                        Roomer,
                        IsSoftAsset
                FROM    dbo.AssetDetail WITH(NOLOCK)
                WHERE   Activer = 1
                  AND   ISNULL(StocktakeId, '') <> @StocktakeId
                  AND   IsSoftAsset = @DepartName;

                RETURN 0;
            END

            IF @QueryType = 'checked'
            BEGIN
                SELECT  a.AssetNum,
                        a.Descriptionx,
                        N'已盘点' AS Status,
                        a.Roomer,
                        a.IsSoftAsset,
                        a.RunStauts,
                        b.LocationDescription AS Location
                FROM    dbo.AssetDetail a WITH(NOLOCK)
                INNER JOIN dbo.Location b WITH(NOLOCK) ON b.LocationName = a.ZoneCode
                WHERE   a.Activer = 1
                  AND   ISNULL(a.StocktakeId, '') = @StocktakeId
                  AND   a.IsSoftAsset = @DepartName;

                RETURN 0;
            END

            -- 默认：按计划和盘点人查询（原 GetPanDianRefList 默认分支）
            IF ISNULL(@PDOperator, '') = ''
                SELECT  AssetNum,
                        Descriptionx,
                        Operator,
                        Roomer
                FROM    dbo.AssetDetail WITH(NOLOCK)
                WHERE   StocktakeId = @StocktakeId;
            ELSE
                SELECT  AssetNum,
                        Descriptionx,
                        Operator,
                        Roomer
                FROM    dbo.AssetDetail WITH(NOLOCK)
                WHERE   StocktakeId = @StocktakeId
                  AND   Operator = @PDOperator;

            RETURN 0;
        END

        SET @I_ReturnMessage = N'ServerMessage:不支持的 Action:' + @Action;
        RETURN -1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        INSERT INTO dbo.SqlProcedureIssueLog (
            ProcName, IssueType, StepCode, Message,
            ErrNumber, ErrLine, ErrMessage, OrBitUserId
        )
        VALUES (
            'PDA_PDOT_InitQuery', N'SQL_EXCEPTION', N'CATCH',
            N'PDOT初始化/查询异常', @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId
        );

        SET @I_ReturnMessage = N'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END
GO

-- =============================================
-- 2. 盘点操作
--    对应接口：operate
--    @Action = check      ：单条扫码盘点
--    @Action = batchCheck ：批量扫码盘点（表值参数 + 集合操作）
--    @Action = unused     ：置闲置
--    @Action = cancel     ：取消盘点
-- =============================================
CREATE PROCEDURE dbo.PDA_PDOT_Operate
    @I_ReturnMessage      NVARCHAR(MAX) = '' OUTPUT,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,
    @I_LanguageId         CHAR(1) = '1',
    @I_PlugInCommand      VARCHAR(5) = '',
    @I_OrBitUserId        CHAR(12) = '',
    @I_OrBitUserName      NVARCHAR(100) = '',
    @I_ResourceId         CHAR(12) = '',
    @I_ResourceName       NVARCHAR(100) = '',
    @I_PKid               CHAR(12) = '',
    @I_ParentPKId         CHAR(12) = '',
    @Action               VARCHAR(20) = '',     -- check / batchCheck / unused / cancel
    @StocktakeId          VARCHAR(12) = '',
    @PDOperator           VARCHAR(20) = '',
    @Pdtype               NVARCHAR(2) = '',
    @ZoneCode             VARCHAR(20) = '',
    @AssetLotSN           NVARCHAR(30) = '',    -- 单条盘点使用
    @AssetNum             NVARCHAR(50) = '',    -- 置闲置/取消盘点使用
    @Assets               dbo.PDOTAssetList READONLY  -- 批量盘点使用
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        SET @I_ReturnMessage = '';
        SET @I_ExceptionFieldName = '';

        -- =============================================
        -- 公共：获取盘点计划对应公司
        -- =============================================
        DECLARE @FactoryName VARCHAR(100) = '';
        DECLARE @FactoryId   VARCHAR(12) = '';

        IF @Action IN ('check', 'batchCheck', 'unused')
        BEGIN
            SELECT  @FactoryName = b.FactoryName,
                    @FactoryId   = a.FactoryId
            FROM    dbo.Stocktake a WITH(NOLOCK)
            INNER JOIN dbo.Factory b WITH(NOLOCK) ON b.FactoryId = a.FactoryId
            WHERE   a.StocktakeId = @StocktakeId;
        END

        -- =============================================
        -- 2.1 单条扫码盘点
        -- =============================================
        IF @Action = 'check'
        BEGIN
            DECLARE @AssetNumLocal    NVARCHAR(50) = UPPER(LTRIM(RTRIM(@AssetLotSN)));
            DECLARE @Description      NVARCHAR(50) = '';
            DECLARE @Roomer           NVARCHAR(30) = '';
            DECLARE @ZoneCodeLocal    VARCHAR(20) = '';
            DECLARE @PDOperatorLocal  VARCHAR(20) = '';
            DECLARE @LocationDesc     NVARCHAR(50) = '';
            DECLARE @PKID             CHAR(12) = '';

            -- 公共参数校验
            IF ISNULL(@StocktakeId, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:请选择盘点计划!';
                SET @I_ExceptionFieldName = 'StocktakeDescription';
                RETURN -1;
            END

            IF ISNULL(@Pdtype, '') NOT IN (N'自盘', N'复盘')
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:请选择盘点类型！';
                RETURN -1;
            END

            IF ISNULL(@AssetNumLocal, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage: 请扫描有效的设备条码!';
                SET @I_ExceptionFieldName = 'AssetLotsn';
                RETURN -1;
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.Location WITH(NOLOCK) WHERE LocationName = @ZoneCode)
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:区域码[' + @ZoneCode + N']在系统中不存在！';
                SET @I_ExceptionFieldName = 'AssetLotsn';
                RETURN -1;
            END

            IF ISNULL(@FactoryName, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:盘点计划不存在或已关闭!';
                SET @I_ExceptionFieldName = 'StocktakeDescription';
                RETURN -1;
            END

            IF NOT EXISTS (SELECT TOP 1 1
                           FROM   dbo.StocktakeCheckList WITH(NOLOCK)
                           WHERE  StocktakeId = @StocktakeId
                             AND  Company = @FactoryName)
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:未导入盘点明细表!' + @FactoryName;
                SET @I_ExceptionFieldName = 'StocktakeDescription';
                RETURN -1;
            END

            -- 设备编号转资产编号
            IF EXISTS (SELECT 1 FROM dbo.AssetDetail WITH(NOLOCK) WHERE EquipmentNumber = @AssetNumLocal)
            BEGIN
                SELECT  @AssetNumLocal = AssetNum
                FROM    dbo.AssetDetail WITH(NOLOCK)
                WHERE   EquipmentNumber = @AssetNumLocal;
            END

            -- 校验资产是否存在且有效
            IF NOT EXISTS (SELECT 1
                           FROM   dbo.AssetDetail WITH(NOLOCK)
                           WHERE  AssetNum = @AssetNumLocal
                             AND  Activer = 1
                             AND  Company = @FactoryName)
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage: 找不到该资产编号，请检查!' + @AssetNumLocal;
                SET @I_ExceptionFieldName = 'AssetLotsn';
                RETURN -1;
            END

            -- 若不在盘点明细中，自动新增“新增配置项”
            IF NOT EXISTS (SELECT 1
                           FROM   dbo.StocktakeCheckList WITH(NOLOCK)
                           WHERE  StocktakeId = @StocktakeId
                             AND  AssetNum = @AssetNumLocal
                             AND  IsCancel = 0)
            BEGIN
                EXEC dbo.SysGetObjectPKId
                     @ObjectId = '',
                     @ObjectName = N'StocktakeCheckList',
                     @PKID = @PKID OUTPUT;

                -- 保留原 OA 通知逻辑
                EXEC dbo.SendMsgToOADoMethod
                     @I_ReturnMessage = @I_ReturnMessage OUTPUT,
                     @TriggerProcedure = N'',
                     @SendMsg = N'数码盘点执行中PDA_PDOT_Operate',
                     @UserName = N'2061399';

                INSERT INTO dbo.StocktakeCheckList
                (
                    StocktakeCheckListId, StocktakeId, AssetDetailid, Company, TypeName,
                    AssetNum, EquipmentNumber, Descriptionx, ExtDescription, UOM,
                    QTY, CostCenter, IsSoftAsset, Roomer, ZoneCode,
                    NotActiver, FirstCheckQTY, FirstCheckOperator, FirstCheckDate, ReCheckQTY,
                    ReCheckOperator, ReCheckDate, Remark, IsCancel, CreateUserId, CreateDate
                )
                SELECT
                    @PKID,
                    @StocktakeId,
                    AssetDetailId,
                    @FactoryName,
                    N'',
                    @AssetNumLocal,
                    N'',
                    a.Descriptionx,
                    a.ExtDescription,
                    a.UOM,
                    a.QTY,
                    a.CostCenter,
                    a.IsSoftAsset,
                    a.Roomer,
                    a.ZoneCode,
                    a.NotActiver,
                    0,
                    '',
                    GETDATE(),
                    0,
                    '',
                    GETDATE(),
                    N'新增配置项',
                    0,
                    '',
                    GETDATE()
                FROM dbo.AssetDetail a WITH(NOLOCK)
                WHERE a.AssetNum = @AssetNumLocal;
            END

            -- 再次校验是否在计划中（防御性）
            IF NOT EXISTS (SELECT 1
                           FROM   dbo.StocktakeCheckList WITH(NOLOCK)
                           WHERE  StocktakeId = @StocktakeId
                             AND  AssetNum = @AssetNumLocal
                             AND  IsCancel = 0)
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:设备编号[' + @AssetNumLocal + N']不在本次盘点计划中！';
                SET @I_ExceptionFieldName = 'AssetLotsn';
                RETURN -1;
            END

            -- 读取资产描述和管理人
            SELECT  @Description = a.Descriptionx,
                    @Roomer      = a.Roomer
            FROM    dbo.AssetDetail a WITH(NOLOCK)
            WHERE   a.AssetNum = @AssetNumLocal
              AND   a.Company = @FactoryName;

            -- 防重复盘点
            IF @Pdtype = N'自盘'
            BEGIN
                IF EXISTS (SELECT 1
                           FROM   dbo.StocktakeCheckList WITH(NOLOCK)
                           WHERE  StocktakeId = @StocktakeId
                             AND  AssetNum = @AssetNumLocal
                             AND  FirstCheckQTY = 1)
                BEGIN
                    SELECT  @ZoneCodeLocal   = ZoneCode,
                            @PDOperatorLocal = FirstCheckOperator
                    FROM    dbo.StocktakeCheckList WITH(NOLOCK)
                    WHERE   StocktakeId = @StocktakeId
                      AND   AssetNum = @AssetNumLocal;

                    SELECT  @LocationDesc = LocationDescription
                    FROM    dbo.Location WITH(NOLOCK)
                    WHERE   LocationName = @ZoneCodeLocal;

                    SET @I_ReturnMessage = N'ServerMessage:设备编号[' + @AssetNumLocal + N']已自盘过，人员['
                                    + @PDOperatorLocal + N']地点[' + ISNULL(@LocationDesc, '') + N']，请勿重复盘点！';
                    SET @I_ExceptionFieldName = 'AssetLotsn';
                    RETURN -1;
                END
            END
            ELSE
            BEGIN
                IF EXISTS (SELECT 1
                           FROM   dbo.StocktakeCheckList WITH(NOLOCK)
                           WHERE  StocktakeId = @StocktakeId
                             AND  AssetNum = @AssetNumLocal
                             AND  ReCheckQTY = 1)
                BEGIN
                    SELECT  @ZoneCodeLocal   = ZoneCode,
                            @PDOperatorLocal = ReCheckOperator
                    FROM    dbo.StocktakeCheckList WITH(NOLOCK)
                    WHERE   StocktakeId = @StocktakeId
                      AND   AssetNum = @AssetNumLocal;

                    SELECT  @LocationDesc = LocationDescription
                    FROM    dbo.Location WITH(NOLOCK)
                    WHERE   LocationName = @ZoneCodeLocal;

                    SET @I_ReturnMessage = N'ServerMessage:设备编号[' + @AssetNumLocal + N']已复盘过，人员['
                                    + @PDOperatorLocal + N']地点[' + ISNULL(@LocationDesc, '') + N']，请勿重复盘点！';
                    SET @I_ExceptionFieldName = 'AssetLotsn';
                    RETURN -1;
                END
            END

            -- 更新盘点明细
            UPDATE  dbo.StocktakeCheckList
            SET     FirstCheckQTY      = IIF(@Pdtype = N'自盘', 1, FirstCheckQTY),
                    FirstCheckOperator = IIF(@Pdtype = N'自盘', @PDOperator, FirstCheckOperator),
                    FirstCheckDate     = IIF(@Pdtype = N'自盘', GETDATE(), FirstCheckDate),
                    ReCheckQTY         = IIF(@Pdtype = N'复盘', 1, ReCheckQTY),
                    ReCheckOperator    = IIF(@Pdtype = N'复盘', @PDOperator, ReCheckOperator),
                    ReCheckDate        = IIF(@Pdtype = N'复盘', GETDATE(), ReCheckDate),
                    ZoneCode           = RTRIM(LTRIM(UPPER(@ZoneCode)))
            WHERE   StocktakeId = @StocktakeId
              AND   AssetNum = @AssetNumLocal;

            -- 更新资产台账
            UPDATE  dbo.AssetDetail
            SET     Operator       = @PDOperator,
                    StockTakeId    = @StocktakeId,
                    NotActiver     = 0,
                    stockCheckDate = GETDATE(),
                    ZoneCode       = RTRIM(LTRIM(UPPER(@ZoneCode)))
            WHERE   AssetNum = @AssetNumLocal
              AND   Company = @FactoryName;

            -- 返回界面展示字段
            SELECT  @Description   AS Description,
                    @Roomer        AS Roomer,
                    @AssetNumLocal AS UnUsedNum;

            SET @I_ExceptionFieldName = 'AssetLotsn';
            SET @I_ReturnMessage = N'ServerMessage:该资产编号[' + RTRIM(@AssetNumLocal) + N'/' + RTRIM(@Description) + N' ]盘点完成!,请扫下一个';
            RETURN 0;
        END

        -- =============================================
        -- 2.2 批量扫码盘点（集合操作，避免 API 层循环）
        -- =============================================
        IF @Action = 'batchCheck'
        BEGIN
            -- 公共参数校验
            IF ISNULL(@StocktakeId, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:请选择盘点计划!';
                SET @I_ExceptionFieldName = 'StocktakeDescription';
                RETURN -1;
            END

            IF ISNULL(@Pdtype, '') NOT IN (N'自盘', N'复盘')
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:请选择盘点类型！';
                RETURN -1;
            END

            IF NOT EXISTS (SELECT 1 FROM @Assets)
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage: 请扫描有效的设备条码!';
                SET @I_ExceptionFieldName = 'AssetLotsn';
                RETURN -1;
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.Location WITH(NOLOCK) WHERE LocationName = @ZoneCode)
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:区域码[' + @ZoneCode + N']在系统中不存在！';
                SET @I_ExceptionFieldName = 'AssetLotsn';
                RETURN -1;
            END

            IF ISNULL(@FactoryName, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:盘点计划不存在或已关闭!';
                SET @I_ExceptionFieldName = 'StocktakeDescription';
                RETURN -1;
            END

            IF NOT EXISTS (SELECT TOP 1 1
                           FROM   dbo.StocktakeCheckList WITH(NOLOCK)
                           WHERE  StocktakeId = @StocktakeId
                             AND  Company = @FactoryName)
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:未导入盘点明细表!' + @FactoryName;
                SET @I_ExceptionFieldName = 'StocktakeDescription';
                RETURN -1;
            END

            -- 批量处理临时表
            IF OBJECT_ID(N'tempdb..#PDOTBatchAssets') IS NOT NULL DROP TABLE #PDOTBatchAssets;

            CREATE TABLE #PDOTBatchAssets
            (
                AssetLotSN   NVARCHAR(30) NOT NULL,
                AssetNum     NVARCHAR(50) NOT NULL,
                IsValid      BIT NOT NULL DEFAULT 1,
                ErrorMsg     NVARCHAR(500) NOT NULL DEFAULT '',
                Description  NVARCHAR(100) NOT NULL DEFAULT '',
                Roomer       NVARCHAR(30) NOT NULL DEFAULT '',
                PRIMARY KEY (AssetLotSN)
            );

            CREATE INDEX IX_PDOTBatchAssets_AssetNum ON #PDOTBatchAssets(AssetNum);

            -- 2.2.1 装入批量数据，统一转大写
            INSERT INTO #PDOTBatchAssets (AssetLotSN, AssetNum)
            SELECT  AssetLotSN,
                    UPPER(LTRIM(RTRIM(AssetLotSN)))
            FROM    @Assets;

            -- 2.2.2 批量转换 EquipmentNumber → AssetNum
            UPDATE  t
            SET     t.AssetNum = a.AssetNum
            FROM    #PDOTBatchAssets t
            INNER JOIN dbo.AssetDetail a WITH(NOLOCK) ON a.EquipmentNumber = t.AssetNum;

            -- 2.2.3 批量校验资产有效性
            UPDATE  t
            SET     t.IsValid = 0,
                    t.ErrorMsg = N'找不到该资产编号，请检查!' + t.AssetNum
            FROM    #PDOTBatchAssets t
            WHERE   NOT EXISTS (
                        SELECT 1
                        FROM   dbo.AssetDetail a WITH(NOLOCK)
                        WHERE  a.AssetNum = t.AssetNum
                          AND  a.Activer = 1
                          AND  a.Company = @FactoryName
                    );

            -- 2.2.4 批量读取资产描述和管理人（仅有效资产）
            UPDATE  t
            SET     t.Description = a.Descriptionx,
                    t.Roomer      = a.Roomer
            FROM    #PDOTBatchAssets t
            INNER JOIN dbo.AssetDetail a WITH(NOLOCK)
                    ON a.AssetNum = t.AssetNum
                   AND a.Company = @FactoryName
            WHERE   t.IsValid = 1;

            -- 2.2.5 批量防重复校验
            IF @Pdtype = N'自盘'
            BEGIN
                UPDATE  t
                SET     t.IsValid = 0,
                        t.ErrorMsg = N'设备编号[' + t.AssetNum + N']已自盘过，人员['
                                     + ISNULL(s.FirstCheckOperator, '') + N']地点['
                                     + ISNULL(l.LocationDescription, '') + N']，请勿重复盘点！'
                FROM    #PDOTBatchAssets t
                INNER JOIN dbo.StocktakeCheckList s WITH(NOLOCK)
                        ON s.StocktakeId = @StocktakeId
                       AND s.AssetNum = t.AssetNum
                       AND s.FirstCheckQTY = 1
                LEFT JOIN dbo.Location l WITH(NOLOCK) ON l.LocationName = s.ZoneCode
                WHERE   t.IsValid = 1;
            END
            ELSE
            BEGIN
                UPDATE  t
                SET     t.IsValid = 0,
                        t.ErrorMsg = N'设备编号[' + t.AssetNum + N']已复盘过，人员['
                                     + ISNULL(s.ReCheckOperator, '') + N']地点['
                                     + ISNULL(l.LocationDescription, '') + N']，请勿重复盘点！'
                FROM    #PDOTBatchAssets t
                INNER JOIN dbo.StocktakeCheckList s WITH(NOLOCK)
                        ON s.StocktakeId = @StocktakeId
                       AND s.AssetNum = t.AssetNum
                       AND s.ReCheckQTY = 1
                LEFT JOIN dbo.Location l WITH(NOLOCK) ON l.LocationName = s.ZoneCode
                WHERE   t.IsValid = 1;
            END

            -- 2.2.6 批量新增“新增配置项”（仅有效且不在计划中的资产）
            IF OBJECT_ID(N'tempdb..#PDOTNewItems') IS NOT NULL DROP TABLE #PDOTNewItems;

            CREATE TABLE #PDOTNewItems
            (
                AssetNum      NVARCHAR(50) NOT NULL PRIMARY KEY,
                AssetLotSN    NVARCHAR(30) NOT NULL,
                NewPKID       CHAR(12) NOT NULL DEFAULT ''
            );

            INSERT INTO #PDOTNewItems (AssetNum, AssetLotSN)
            SELECT  t.AssetNum, t.AssetLotSN
            FROM    #PDOTBatchAssets t
            WHERE   t.IsValid = 1
              AND   NOT EXISTS (
                        SELECT 1
                        FROM   dbo.StocktakeCheckList s WITH(NOLOCK)
                        WHERE  s.StocktakeId = @StocktakeId
                          AND  s.AssetNum = t.AssetNum
                          AND  s.IsCancel = 0
                    );

            -- 为新增配置项逐条取号（仅新增部分，数量通常很少）
            DECLARE @NewAssetNum NVARCHAR(50);
            DECLARE @NewPKID     CHAR(12);

            WHILE EXISTS (SELECT 1 FROM #PDOTNewItems WHERE NewPKID = '')
            BEGIN
                SELECT TOP 1 @NewAssetNum = AssetNum
                FROM #PDOTNewItems
                WHERE NewPKID = '';

                EXEC dbo.SysGetObjectPKId
                     @ObjectId = '',
                     @ObjectName = N'StocktakeCheckList',
                     @PKID = @NewPKID OUTPUT;

                UPDATE #PDOTNewItems
                SET NewPKID = @NewPKID
                WHERE AssetNum = @NewAssetNum;
            END

            -- 批量插入新增配置项
            IF EXISTS (SELECT 1 FROM #PDOTNewItems)
            BEGIN
                -- 保留原 OA 通知逻辑（批量场景下只发一次汇总通知）
                EXEC dbo.SendMsgToOADoMethod
                     @I_ReturnMessage = @I_ReturnMessage OUTPUT,
                     @TriggerProcedure = N'',
                     @SendMsg = N'数码盘点执行中PDA_PDOT_Operate批量新增配置项',
                     @UserName = N'2061399';

                INSERT INTO dbo.StocktakeCheckList
                (
                    StocktakeCheckListId, StocktakeId, AssetDetailid, Company, TypeName,
                    AssetNum, EquipmentNumber, Descriptionx, ExtDescription, UOM,
                    QTY, CostCenter, IsSoftAsset, Roomer, ZoneCode,
                    NotActiver, FirstCheckQTY, FirstCheckOperator, FirstCheckDate, ReCheckQTY,
                    ReCheckOperator, ReCheckDate, Remark, IsCancel, CreateUserId, CreateDate
                )
                SELECT
                    n.NewPKID,
                    @StocktakeId,
                    a.AssetDetailId,
                    @FactoryName,
                    N'',
                    n.AssetNum,
                    N'',
                    a.Descriptionx,
                    a.ExtDescription,
                    a.UOM,
                    a.QTY,
                    a.CostCenter,
                    a.IsSoftAsset,
                    a.Roomer,
                    a.ZoneCode,
                    a.NotActiver,
                    0,
                    '',
                    GETDATE(),
                    0,
                    '',
                    GETDATE(),
                    N'新增配置项',
                    0,
                    '',
                    GETDATE()
                FROM #PDOTNewItems n
                INNER JOIN dbo.AssetDetail a WITH(NOLOCK) ON a.AssetNum = n.AssetNum;
            END

            -- 2.2.7 批量更新有效资产的盘点明细
            UPDATE  s
            SET     FirstCheckQTY      = IIF(@Pdtype = N'自盘', 1, s.FirstCheckQTY),
                    FirstCheckOperator = IIF(@Pdtype = N'自盘', @PDOperator, s.FirstCheckOperator),
                    FirstCheckDate     = IIF(@Pdtype = N'自盘', GETDATE(), s.FirstCheckDate),
                    ReCheckQTY         = IIF(@Pdtype = N'复盘', 1, s.ReCheckQTY),
                    ReCheckOperator    = IIF(@Pdtype = N'复盘', @PDOperator, s.ReCheckOperator),
                    ReCheckDate        = IIF(@Pdtype = N'复盘', GETDATE(), s.ReCheckDate),
                    ZoneCode           = RTRIM(LTRIM(UPPER(@ZoneCode)))
            FROM    dbo.StocktakeCheckList s
            INNER JOIN #PDOTBatchAssets t
                    ON s.StocktakeId = @StocktakeId
                   AND s.AssetNum = t.AssetNum
            WHERE   t.IsValid = 1;

            -- 2.2.8 批量更新有效资产的台账
            UPDATE  a
            SET     Operator       = @PDOperator,
                    StockTakeId    = @StocktakeId,
                    NotActiver     = 0,
                    stockCheckDate = GETDATE(),
                    ZoneCode       = RTRIM(LTRIM(UPPER(@ZoneCode)))
            FROM    dbo.AssetDetail a
            INNER JOIN #PDOTBatchAssets t
                    ON a.AssetNum = t.AssetNum
                   AND a.Company = @FactoryName
            WHERE   t.IsValid = 1;

            -- 2.2.9 返回每条处理结果
            SELECT  AssetLotSN,
                    AssetNum,
                    IsValid AS Success,
                    CASE WHEN IsValid = 1 THEN N'盘点完成' ELSE ErrorMsg END AS Message,
                    Description,
                    Roomer
            FROM    #PDOTBatchAssets;

            -- 汇总提示
            DECLARE @SuccessCount INT = 0;
            DECLARE @FailCount    INT = 0;

            SELECT  @SuccessCount = SUM(IIF(IsValid = 1, 1, 0)),
                    @FailCount    = SUM(IIF(IsValid = 0, 1, 0))
            FROM    #PDOTBatchAssets;

            SET @I_ReturnMessage = N'ServerMessage:批量盘点完成：成功 ' + CAST(@SuccessCount AS NVARCHAR(10))
                                   + N' 条，失败 ' + CAST(@FailCount AS NVARCHAR(10)) + N' 条';

            DROP TABLE #PDOTBatchAssets;
            IF OBJECT_ID(N'tempdb..#PDOTNewItems') IS NOT NULL DROP TABLE #PDOTNewItems;

            RETURN 0;
        END

        -- =============================================
        -- 2.3 置闲置
        -- =============================================
        IF @Action = 'unused'
        BEGIN
            IF ISNULL(@AssetNum, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:请先盘点后再点击闲置！';
                RETURN -1;
            END

            UPDATE  dbo.AssetDetail
            SET     NotActiver = 1
            WHERE   AssetNum = @AssetNum
              AND   Company = @FactoryName;

            UPDATE  b
            SET     NotActiver = 1
            FROM    dbo.Stocktake a WITH(NOLOCK)
            INNER JOIN dbo.StocktakeCheckList b WITH(NOLOCK) ON b.StocktakeId = a.StocktakeId
            WHERE   b.AssetNum = @AssetNum
              AND   b.Company = @FactoryName
              AND   a.StocktakeId = @StocktakeId;

            SET @I_ExceptionFieldName = 'AssetLotsn';
            SET @I_ReturnMessage = N'ServerMessage:资产编号[' + @AssetNum + N']已闲置';
            RETURN 0;
        END

        -- =============================================
        -- 2.4 取消盘点
        -- =============================================
        IF @Action = 'cancel'
        BEGIN
            IF ISNULL(@StocktakeId, '') = '' OR ISNULL(@AssetNum, '') = ''
            BEGIN
                SET @I_ReturnMessage = N'ServerMessage:参数不完整';
                RETURN -1;
            END

            UPDATE  dbo.AssetDetail
            SET     StockTakeId = ''
            WHERE   Activer = 1
              AND   ISNULL(StocktakeId, '') = @StocktakeId
              AND   AssetNum = @AssetNum;

            SET @I_ReturnMessage = N'ServerMessage: 取消成功';
            RETURN 0;
        END

        SET @I_ReturnMessage = N'ServerMessage:不支持的 Action:' + @Action;
        RETURN -1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        INSERT INTO dbo.SqlProcedureIssueLog (
            ProcName, IssueType, StepCode, Message,
            ErrNumber, ErrLine, ErrMessage, OrBitUserId
        )
        VALUES (
            'PDA_PDOT_Operate', N'SQL_EXCEPTION', N'CATCH',
            N'PDOT盘点操作异常', @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId
        );

        SET @I_ReturnMessage = N'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END
GO

-- =============================================
-- 调用示例（参考 .AGENTS/skills/dev-utils-toolkit/functions/call-api.md 风格）
-- =============================================

-- 3.1 初始化
-- DECLARE @I_ReturnMessage NVARCHAR(MAX) = '';
-- DECLARE @I_ExceptionFieldName NVARCHAR(100) = '';
-- EXEC dbo.PDA_PDOT_InitQuery
--      @I_ReturnMessage = @I_ReturnMessage OUTPUT,
--      @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
--      @I_OrBitUserId = 'AIAssistant',
--      @Action = 'init',
--      @PDOperator = '2061399';
-- SELECT @I_ReturnMessage;

-- 3.2 查询已盘点
-- DECLARE @I_ReturnMessage NVARCHAR(MAX) = '';
-- DECLARE @I_ExceptionFieldName NVARCHAR(100) = '';
-- EXEC dbo.PDA_PDOT_InitQuery
--      @I_ReturnMessage = @I_ReturnMessage OUTPUT,
--      @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
--      @I_OrBitUserId = 'AIAssistant',
--      @Action = 'query',
--      @QueryType = 'checked',
--      @StocktakeId = 'PD1500008',
--      @DepartName = N'生产部';
-- SELECT @I_ReturnMessage;

-- 3.3 单条盘点
-- DECLARE @I_ReturnMessage NVARCHAR(MAX) = '';
-- DECLARE @I_ExceptionFieldName NVARCHAR(100) = '';
-- EXEC dbo.PDA_PDOT_Operate
--      @I_ReturnMessage = @I_ReturnMessage OUTPUT,
--      @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
--      @I_OrBitUserId = 'AIAssistant',
--      @Action = 'check',
--      @StocktakeId = 'PD1500008',
--      @PDOperator = '2061399',
--      @Pdtype = N'自盘',
--      @ZoneCode = 'A-01-01',
--      @AssetLotSN = 'ZC20240001';
-- SELECT @I_ReturnMessage;

-- 3.4 批量盘点
-- DECLARE @I_ReturnMessage NVARCHAR(MAX) = '';
-- DECLARE @I_ExceptionFieldName NVARCHAR(100) = '';
-- DECLARE @Assets dbo.PDOTAssetList;
-- INSERT INTO @Assets VALUES ('ZC20240001'), ('ZC20240002'), ('ZC20240003');
-- EXEC dbo.PDA_PDOT_Operate
--      @I_ReturnMessage = @I_ReturnMessage OUTPUT,
--      @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
--      @I_OrBitUserId = 'AIAssistant',
--      @Action = 'batchCheck',
--      @StocktakeId = 'PD1500008',
--      @PDOperator = '2061399',
--      @Pdtype = N'自盘',
--      @ZoneCode = 'A-01-01',
--      @Assets = @Assets;
-- SELECT @I_ReturnMessage;

-- 3.5 置闲置
-- DECLARE @I_ReturnMessage NVARCHAR(MAX) = '';
-- DECLARE @I_ExceptionFieldName NVARCHAR(100) = '';
-- EXEC dbo.PDA_PDOT_Operate
--      @I_ReturnMessage = @I_ReturnMessage OUTPUT,
--      @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
--      @I_OrBitUserId = 'AIAssistant',
--      @Action = 'unused',
--      @StocktakeId = 'PD1500008',
--      @AssetNum = 'ZC20240001';
-- SELECT @I_ReturnMessage;

-- 3.6 取消盘点
-- DECLARE @I_ReturnMessage NVARCHAR(MAX) = '';
-- DECLARE @I_ExceptionFieldName NVARCHAR(100) = '';
-- EXEC dbo.PDA_PDOT_Operate
--      @I_ReturnMessage = @I_ReturnMessage OUTPUT,
--      @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
--      @I_OrBitUserId = 'AIAssistant',
--      @Action = 'cancel',
--      @StocktakeId = 'PD1500008',
--      @AssetNum = 'ZC20240001';
-- SELECT @I_ReturnMessage;
