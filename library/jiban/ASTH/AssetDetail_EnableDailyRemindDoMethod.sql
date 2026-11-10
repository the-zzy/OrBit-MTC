-- =============================================
-- Author:      <xiongss>
-- Create date: <2026-06-05>
-- Description: 开启设备每日点检提醒
--              验证负责人工号，开启每日提醒并设置负责人
--              支持批量设置（@I_Parameter传入逗号分隔的主键ID）
-- =============================================
CREATE   PROCEDURE [dbo].[AssetDetail_EnableDailyRemindDoMethod]
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
    -- 以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现
    @ResponsibleNumber VARCHAR(20) = ''  ,            -- 负责人工号
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
        DECLARE @PersonName NVARCHAR(100) = '';
        DECLARE @IsActivity BIT = 0;
        DECLARE @SuccessCount INT = 0; 
        DECLARE @CurrentAssetId CHAR(12) = ''; 

        -- 检查设备ID是否提供
        IF LTRIM(RTRIM(ISNULL(@I_Parameter, ''))) = ''
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:设备ID不能为空！';
            SET @I_ExceptionFieldName = 'I_Parameter';
            RETURN -1;
        END;
		
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
            SET @I_ReturnMessage = N'ServerMessage:密码错误！';
            SET @I_ExceptionFieldName = 'Password';
            RETURN -1;
        END;


        -- 检查负责人工号是否提供
        IF LTRIM(RTRIM(ISNULL(@ResponsibleNumber, ''))) = ''
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:负责人工号不能为空！';
            SET @I_ExceptionFieldName = 'ResponsibleNumber';
            RETURN -1;
        END;

        -- 验证负责人工号是否存在且启用
        SELECT
            @PersonName = PersonName,
            @IsActivity = ISNULL(IsActivity, 0)
        FROM dbo.PersonInfo WITH (NOLOCK)
        WHERE PersonNumber = @ResponsibleNumber;

        IF @PersonName IS NULL
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:工号[' + @ResponsibleNumber + N']不存在！';
            SET @I_ExceptionFieldName = 'ResponsibleNumber';
            RETURN -1;
        END;

        IF @IsActivity = 0
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:工号[' + @ResponsibleNumber + N'](' + @PersonName + N')已停用，无法设置为负责人！';
            SET @I_ExceptionFieldName = 'ResponsibleNumber';
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
		 
		


		IF EXISTS (SELECT 1 FROM  #TempAssetIds t
			LEFT  JOIN  dbo.AssetDetail a ON t.AssetDetailId = a.AssetDetailId WHERE a.AssetDetailid IS NULL )
		BEGIN 
			SET @I_ReturnMessage =  N'ServerMessage:设备ID[' + @CurrentAssetId + N']不存在或已删除；';
            RETURN -1;
		END

		IF EXISTS (SELECT 1 FROM  #TempAssetIds t
			INNER JOIN  dbo.AssetDetail a ON t.AssetDetailId = a.AssetDetailId WHERE a.IsDailyRemind=1)
		BEGIN 
			SET @I_ReturnMessage =  N'ServerMessage:设备存在已开启每日提醒，请检查！';
            RETURN -1;
		END  
        -- 批量更新：开启每日提醒，设置负责人
        UPDATE a
        SET
            a.IsDailyRemind = 1,
            a.CheckResponsible = @ResponsibleNumber,
            a.ModifyUser = @I_OrBitUserName,
            a.ModifiDate = GETDATE()
        FROM #TempAssetIds t
        INNER JOIN  dbo.AssetDetail a ON t.AssetDetailId = a.AssetDetailId
        WHERE   (a.DeleteFlag = 0 OR a.DeleteFlag IS NULL) 
            AND ISNULL(a.IsDailyRemind, 0) = 0;
		SET @SuccessCount = @@ROWCOUNT; 

        -- 清理临时表
        DROP TABLE #TempAssetIds;

        -- 返回成功消息
        SET @I_ReturnMessage = N'ServerMessage:操作完成！成功' + CAST(@SuccessCount AS NVARCHAR(10)) + N'个'; 
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
            N'Proc_AssetDetail_EnableDailyRemind',
            N'SQL_EXCEPTION',
            N'CATCH',
            N'开启每日提醒异常',
            @ErrNum,
            @ErrLine,
            @ErrMsg,
            @I_OrBitUserId
        );

        SET @I_ReturnMessage = N'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
