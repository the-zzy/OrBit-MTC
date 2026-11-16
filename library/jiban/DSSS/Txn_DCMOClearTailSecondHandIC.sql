
CREATE PROCEDURE [dbo].[Txn_DCMOClearTailSecondHandIC]
    @I_Sender             NVARCHAR(200)  = '' ,
    @I_ReturnMessage      NVARCHAR(MAX)  = '' OUTPUT ,
    @I_ExceptionFieldName NVARCHAR(100)  = '' OUTPUT ,
    @I_LanguageId         CHAR(1)        = '1' ,
    @I_PlugInCommand      VARCHAR(5)     = '' ,
    @I_OrBitUserId        CHAR(12)       = '' ,
    @I_OrBitUserName      NVARCHAR(100)  = '' ,
    @I_ResourceId         CHAR(12)       = '' ,
    @I_ResourceName       NVARCHAR(100)  = '' ,
    @I_PKId               CHAR(12)       = '' ,
    @I_SourcePKId         CHAR(12)       = '' ,
    @I_ParentPKId         CHAR(12)       = '' ,
    @I_Parameter          NVARCHAR(100)  = '' ,
    -- ── 业务参数（与界面字段逐字同名，只保留必要的 6 个）──
    @MOId                 CHAR(12)       = '' ,
    @MOName               NVARCHAR(50)   = '' ,
    @Operator             NVARCHAR(50)   = '' ,
    @Side                 VARCHAR(10)    = '' ,
    @LotSN                NVARCHAR(50)   = '' ,
    @SecondHandICSN       NVARCHAR(100)  = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    BEGIN TRY
        SET @I_ReturnMessage = '';
        SET @I_ExceptionFieldName = '';

        -- ── 入参规范化 ─────────────────────────────────────
        SET @LotSN          = UPPER(RTRIM(LTRIM(ISNULL(@LotSN, ''))));
        SET @Operator       = UPPER(RTRIM(LTRIM(ISNULL(@Operator, ''))));
        SET @SecondHandICSN = UPPER(RTRIM(LTRIM(ISNULL(@SecondHandICSN, ''))));
        SET @Side           = UPPER(RTRIM(LTRIM(ISNULL(@Side, ''))));

        DECLARE @LotId    CHAR(12);
        DECLARE @LotStatus CHAR(1);
        DECLARE @LotMOId  CHAR(12);
        DECLARE @ProductId CHAR(12);
        DECLARE @NewId    CHAR(12);
        DECLARE @Cnt      INT;

        -- ── ⓪ 清空按钮：只重置界面，不读写任何表 ──────────
        IF @I_Sender = 'BtnClear'
        BEGIN
            SELECT  '' AS LotSN, '' AS SecondHandICSN, '' AS Operator, 'ok.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'LotSN';
            SET @I_ReturnMessage = 'ServerMessage:数据清除成功，请重新扫描产品条码!';
            RETURN 0;
        END

        -- ── ① 工单号 ───────────────────────────────────────
        IF ISNULL(@MOId, '') = ''
        BEGIN
            SELECT 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'MOName';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入工单号!';
            RETURN -1;
        END

        -- ── ② 操作员 ───────────────────────────────────────
        IF @Operator = ''
        BEGIN
            SELECT 'ok.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'Operator';
            SET @I_ReturnMessage = 'ServerMessage:say{OK.wav}请输入操作员工号!';
            RETURN -1;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.PersonInfo WITH (NOLOCK)
                       WHERE PersonNumber = @Operator AND IsActivity = 1)
        BEGIN
            SELECT 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'Operator';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}操作员工号 [' + @Operator + '] 不存在或已离职!';
            RETURN -1;
        END

        -- ── ③ 面别 ─────────────────────────────────────────
        IF @Side = ''
        BEGIN
            SELECT 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'Side';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请选择 A/B 面!';
            RETURN -1;
        END

        -- ── ④ 批号 ─────────────────────────────────────────
        IF @LotSN = ''
        BEGIN
            SELECT '' AS LotSN, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'LotSN';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入产品条码!';
            RETURN -1;
        END

        SELECT  @LotId = LotId, @LotStatus = LotStatus, @LotMOId = MOId, @ProductId = ProductId
        FROM    dbo.Lot WITH (NOLOCK)
        WHERE   LotSN = @LotSN;

        IF ISNULL(@LotId, '') = ''
        BEGIN
            SELECT '' AS LotSN, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'LotSN';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 不存在!';
            RETURN -1;
        END

        IF ISNULL(@LotStatus, '0') <> '1'
        BEGIN
            SELECT '' AS LotSN, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'LotSN';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 状态不可用!';
            RETURN -1;
        END

        IF ISNULL(@LotMOId, '') <> @MOId
        BEGIN
            SELECT '' AS LotSN, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'LotSN';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 不属于该工单';
            RETURN -1;
        END

        -- ── ⑤ 二手IC（非空才校验；只查是否在仓库，不比对是否等于批号）──
        IF @SecondHandICSN <> ''
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Lot WITH (NOLOCK) WHERE LotSN = @SecondHandICSN)
            BEGIN
                SELECT '' AS SecondHandICSN, 'error.png' AS WarnImage;
                SET @I_ExceptionFieldName = 'SecondHandICSN';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}二手IC条码 [' + @SecondHandICSN + '] 不在仓库，不能清尾!';
                RETURN -1;
            END
        END

        -- ── ⑥ 不允许重复清尾（同一批号只留一条有效记录）──
        IF EXISTS (SELECT 1 FROM dbo.DCMOClearTailRecord WITH (NOLOCK)
                   WHERE LotSN = @LotSN AND IsCancel = 0)
        BEGIN
            SELECT '' AS LotSN, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'LotSN';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 已清尾，不能重复清尾!';
            RETURN -1;
        END

        -- ── ⑦ 写记录（只插这一张表）───────────────────────
        SET @NewId = dbo.Fn_GetObjectPKId(12, 'DCMOClearTailRecord', NEXT VALUE FOR dbo.DCMOClearTailRecord_PK);

        INSERT INTO dbo.DCMOClearTailRecord (
            DCMOClearTailRecordId, MOId, MOName, ProductId, ProductName,
            WorkcenterId, WorkcenterName, Side, LotId, LotSN,
            SecondHandICSN, Operator, UserId, ResourceId,
            ClearDate, CreateDate, ModifyDate, IsCancel
        )
        SELECT  @NewId, @MOId, ISNULL(@MOName, ''), ISNULL(@ProductId, ''), ISNULL(pr.prdname, ''),
               ISNULL(us.WorkcenterId, ''), ISNULL(wc.WorkcenterName, ''), @Side, @LotId, @LotSN,
               @SecondHandICSN, @Operator, @I_OrBitUserId, @I_ResourceId,
               GETDATE(), GETDATE(), GETDATE(), 0
        FROM    (SELECT 1 AS x) AS t
        LEFT JOIN dbo.Product pr   WITH (NOLOCK) ON pr.ProductId = @ProductId
        LEFT JOIN dbo.SysUser us   WITH (NOLOCK) ON us.UserId = @I_OrBitUserId
        LEFT JOIN dbo.Workcenter wc WITH (NOLOCK) ON wc.WorkcenterId = us.WorkcenterId;

        SELECT '' AS LotSN, '' AS SecondHandICSN, 'ok.png' AS WarnImage;
        SET @I_ExceptionFieldName = 'LotSN';
        SET @I_ReturnMessage = 'ServerMessage:say{OK.wav}清尾成功！产品条码[' + @LotSN + ']' +
            CASE WHEN @SecondHandICSN = '' THEN '' ELSE '，二手IC[' + @SecondHandICSN + ']' END;
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum  INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg  NVARCHAR(4000) = ERROR_MESSAGE();

        INSERT INTO dbo.SqlProcedureIssueLog (
            ProcName, IssueType, StepCode, Message, ErrNumber, ErrLine, ErrMessage, OrBitUserId
        ) VALUES (
            N'Txn_DCMOClearTailSecondHandIC', N'SQL_EXCEPTION', N'CATCH',
            N'工单清尾[二手IC]异常', @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId
        );

        SELECT 'error.png' AS WarnImage;
        SET @I_ReturnMessage = N'ServerMessage:' + @ErrMsg;
        RETURN -1;
    END CATCH
END
