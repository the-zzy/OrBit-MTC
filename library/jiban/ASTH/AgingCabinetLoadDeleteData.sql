

-- =============================================

-- Author:            <1003153>

-- Create date:       <2026.10.26>

-- Description:       老化柜负载删除（禁止删除，仅作废由业务另行约定）

-- =============================================

CREATE PROCEDURE [dbo].[AgingCabinetLoadDeleteData]

    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,

    @I_LanguageId CHAR(1) = '1',

    @I_PlugInCommand VARCHAR(5) = '',

    @I_OrBitUserId CHAR(12) = '',

    @I_OrBitUserName NVARCHAR(100) = '',

    @I_ResourceId CHAR(12) = '',

    @I_ResourceName NVARCHAR(100) = '',

    @I_PKId CHAR(12) = '',

    @I_ParentPKId CHAR(12) = '',

    @I_Parameter NVARCHAR(100) = ''

AS

BEGIN

    BEGIN TRY

        SET NOCOUNT ON;

        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



        SET @I_ReturnMessage = N'ServerMessage:负载档案不允许删除，如需调整请联系管理员';

        RETURN -1;

    END TRY

    BEGIN CATCH

        DECLARE @ErrNum INT = ERROR_NUMBER();

        DECLARE @ErrLine INT = ERROR_LINE();

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();



        INSERT INTO dbo.SqlProcedureIssueLog (

            ProcName, IssueType, StepCode, Message, ErrNumber, ErrLine, ErrMessage, OrBitUserId

        )

        VALUES (

            N'AgingCabinetLoadDeleteData', N'SQL_EXCEPTION', N'CATCH', N'老化柜负载DeleteData异常',

            @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId

        );



        SET @I_ReturnMessage = N'ServerMessage:' + @ErrMsg;

        RETURN -1;

    END CATCH

END

