-- =============================================
-- Author:      <xiongss>
-- Create date: <2026-06-05>
-- Description: 取消设备每日点检提醒
--              关闭每日提醒并清空负责人
--              支持批量取消（@I_Parameter传入逗号分隔的主键ID）
--              需要密码验证（密码为当天月日，例如0605）
-- =============================================
CREATE   PROCEDURE [dbo].[AssetDetail_DisableDailyRemindDoMethod]
    @I_Sender NVARCHAR(200) = '',                    -- 客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,      -- 返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT, -- 向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1',                     -- 客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '',                -- 插件命令
    @I_OrBitUserId CHAR(12) = '',                    -- 用户ID
    @I_OrBitUserName NVARCHAR(100) = '',             -- 用户名
    @I_ResourceId CHAR(12) = '',                     -- 资源ID
    @I_ResourceName NVARCHAR(100) = '',              -- 资源名
    @I_PKid CHAR(12) = '',                           -- 主键
    @I_ParentPKId CHAR(12) = '',                     -- 父级主键
    @I_Parameter NVARCHAR(100) = '',                 -- 插件参数（设备ID，支持逗号分隔）
    @Password NVARCHAR(20) = ''                    -- 密码（当天月日，例如0605）
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        -- 初始化
        SET @I_ReturnMessage = '';
        SET @I_ExceptionFieldName = '';

        -- 变量声明
        DECLARE @SuccessCount INT = 0;
        DECLARE @FailCount INT = 0;
        DECLARE @SkipCount INT = 0; 
        DECLARE @CurrentPassword NVARCHAR(20) = '';

        -- 验证密码：当天月日（例如0605）
        SET @CurrentPassword = FORMAT(GETDATE(), 'MMdd');

        IF LTRIM(RTRIM(ISNULL(@Password, ''))) = ''
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:密码不能为空！';
            SET @I_ExceptionFieldName = 'Password';
            RETURN -1;
        END;

        IF @Password <> @CurrentPassword
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:密码错误！ ';
            SET @I_ExceptionFieldName = 'Password';
            RETURN -1;
        END;

        -- 检查设备ID是否提供
        IF LTRIM(RTRIM(ISNULL(@I_Parameter, ''))) = ''
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:设备ID不能为空！';
            SET @I_ExceptionFieldName = 'I_Parameter';
            RETURN -1;
        END;

        -- 创建临时表存储设备ID
        IF OBJECT_ID(N'tempdb..#TempAssetIds') IS NOT NULL DROP TABLE #TempAssetIds;

        CREATE TABLE #TempAssetIds (
            AssetDetailId CHAR(12)
        );

        -- 解析分号分隔的设备ID
        DECLARE @Pos INT = 0;
        DECLARE @NextPos INT = 0;
        DECLARE @AssetId CHAR(12) = '';
        DECLARE @ParameterList NVARCHAR(100) = LTRIM(RTRIM(@I_Parameter)) + ';';

        WHILE CHARINDEX(';', @ParameterList) > 0
        BEGIN
            SET @NextPos = CHARINDEX(';', @ParameterList);
            SET @AssetId = LTRIM(RTRIM(SUBSTRING(@ParameterList, 1, @NextPos - 1)));

            IF @AssetId <> ''
            BEGIN
                INSERT INTO #TempAssetIds (AssetDetailId) VALUES (@AssetId);
            END;

            SET @ParameterList = SUBSTRING(@ParameterList, @NextPos + 1, LEN(@ParameterList));
        END;
		 
        -- 统计不存在或已删除的设备
        SELECT @FailCount = COUNT(1)
        FROM #TempAssetIds t
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.AssetDetail a WITH (NOLOCK)
            WHERE a.AssetDetailId = t.AssetDetailId
             AND(a.DeleteFlag = 0 OR a.DeleteFlag IS NULL) 
        );

        IF @FailCount > 0
        BEGIN
            SET @I_ReturnMessage ='ServerMessage:' + CAST(@FailCount AS NVARCHAR(10)) + N'个设备不存在或已删除；';
            RETURN -1;
        END;

        -- 统计未开启提醒的设备（跳过）
        SELECT @SkipCount = COUNT(1)
        FROM #TempAssetIds t
        INNER JOIN dbo.AssetDetail a WITH (NOLOCK) ON a.AssetDetailId = t.AssetDetailId
        WHERE  (a.DeleteFlag = 0 OR a.DeleteFlag IS NULL) 
            AND ISNULL(a.IsDailyRemind, 0) = 0;

        IF @SkipCount > 0
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:' + CAST(@SkipCount AS NVARCHAR(10)) + N'个设备未开启提醒，请检查；';
            RETURN -1;
        END;

        -- 批量更新：关闭每日提醒，清空负责人
        UPDATE a
        SET
            a.IsDailyRemind = 0,
            a.CheckResponsible = '',
            a.ModifyUser = @I_OrBitUserName,
            a.ModifiDate = GETDATE()
        FROM dbo.AssetDetail a
        INNER JOIN #TempAssetIds t ON t.AssetDetailId = a.AssetDetailId
        WHERE (a.DeleteFlag = 0 OR a.DeleteFlag IS NULL) 
            AND ISNULL(a.IsDailyRemind, 0) = 1;

        SET @SuccessCount = @@ROWCOUNT;

        -- 清理临时表
        DROP TABLE #TempAssetIds;

        -- 返回成功消息
        SET @I_ReturnMessage ='ServerMessage:'+N'操作完成！成功' + CAST(@SuccessCount AS NVARCHAR(10)) + N'个。' ;
        RETURN 0;

    END TRY
    BEGIN CATCH
        -- 清理临时表
        IF OBJECT_ID(N'tempdb..#TempAssetIds') IS NOT NULL DROP TABLE #TempAssetIds;

        -- 记录异常信息
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        INSERT INTO dbo.SqlProcedureIssueLog (
            ProcName,
            IssueType,
            StepCode,
            Message,
            ErrNumber,
            ErrLine,
            ErrMessage,
            OrBitUserId
        )
        VALUES (
            N'AssetDetail_DisableDailyRemindDoMethod',
            N'SQL_EXCEPTION',
            N'CATCH',
            N'取消每日提醒异常',
            @ErrNum,
            @ErrLine,
            @ErrMsg,
            @I_OrBitUserId
        );

        SET @I_ReturnMessage = N'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
