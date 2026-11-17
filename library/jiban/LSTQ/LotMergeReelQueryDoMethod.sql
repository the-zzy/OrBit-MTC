
CREATE PROCEDURE dbo.LotMergeReelQueryDoMethod
    @I_Sender NVARCHAR(200) = '' ,
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT ,
    @I_LanguageId CHAR(1) = '1' ,
    @I_PlugInCommand VARCHAR(5) = '' ,
    @I_OrBitUserId CHAR(12) = '' ,
    @I_OrBitUserName NVARCHAR(100) = '' ,
    @I_ResourceId CHAR(12) = '' ,
    @I_ResourceName NVARCHAR(100) = '' ,
    @I_PKid CHAR(12) = '' ,
    @I_ParentPKId CHAR(12) = '' ,
    @I_Parameter NVARCHAR(100) = '' ,
    @LotSN NVARCHAR(50) = '' ,
    @FromDate DATETIME = NULL ,
    @EndDate DATETIME = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        SET @I_ReturnMessage = N'';
        SET @I_ExceptionFieldName = N'';

        IF @I_Sender <> N'btnSMTReelMergeQuery'
            RETURN 0;

        IF ISNULL(LTRIM(RTRIM(@LotSN)), N'') = N''
           AND @FromDate IS NULL
           AND @EndDate IS NULL
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:批号、开始日期、结束日期不能同时为空!';
            SET @I_ExceptionFieldName = N'LotSN';
            RETURN -1;
        END

        IF @FromDate IS NOT NULL AND @EndDate IS NOT NULL AND @EndDate < @FromDate
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:开始日期不能大于结束日期!';
            SET @I_ExceptionFieldName = N'FromDate';
            RETURN -1;
        END

        SELECT
            ISNULL(NULLIF(LTRIM(RTRIM(m.MergeSN)), N''), N'(扫描中)') AS '合盘单号',
            i.LotSN                                                    AS '批次',
            CAST(i.LotQty AS DECIMAL(18, 4))                           AS '批次数量',
            CAST(m.TotalQty AS DECIMAL(18, 4))                         AS '合盘总数量',
            m.ReelCount                                                AS '料盘数',
            ISNULL(m.MachineNumber, N'')                               AS '机台',
            ISNULL(m.Operator, N'')                                    AS '操作员',
            m.CreateDate                                               AS '合盘时间',
            CASE WHEN m.IsCancel = 1 THEN N'已作废' ELSE N'正常' END    AS '状态',
            ISNULL(pr.ProductName, N'')                                AS '料号',
            ISNULL(p.ProductDescription, N'')                          AS '料号描述'
        FROM dbo.SMTReelMergeItem i WITH (NOLOCK)
        INNER JOIN dbo.SMTReelMerge m WITH (NOLOCK)
            ON m.SMTReelMergeId = i.SMTReelMergeId
        LEFT JOIN dbo.Product p WITH (NOLOCK)
            ON p.ProductId = m.ProductId
        LEFT JOIN dbo.ProductRoot pr WITH (NOLOCK)
            ON pr.ProductRootId = p.ProductRootId
        WHERE ( ISNULL(LTRIM(RTRIM(@LotSN)), N'') = N'' OR i.LotSN = @LotSN )
          AND ( @FromDate IS NULL OR m.CreateDate >= @FromDate )
          AND ( @EndDate IS NULL OR m.CreateDate < DATEADD(DAY, 1, CONVERT(DATETIME, CONVERT(DATE, @EndDate))) )
        ORDER BY m.CreateDate DESC, i.LotSN;

        SET @I_ReturnMessage = N'ServerMessage:查询成功';
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        BEGIN TRY
            INSERT INTO dbo.SqlProcedureIssueLog (
                ProcName, IssueType, StepCode, Message,
                ErrNumber, ErrLine, ErrMessage, OrBitUserId
            )
            VALUES (
                N'LotMergeReelQueryDoMethod', N'SQL_EXCEPTION', N'CATCH',
                N'合盘来源查询异常', @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId
            );
        END TRY
        BEGIN CATCH
        END CATCH

        SET @I_ReturnMessage = N'ServerMessage:' + ISNULL(@ErrMsg, N'查询失败');
        SET @I_ExceptionFieldName = N'';
        RETURN -1;
    END CATCH
END
