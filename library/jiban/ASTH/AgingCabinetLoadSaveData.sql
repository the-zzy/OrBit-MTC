

-- =============================================

-- Author:            <1003153>

-- Create date:       <2026.10.26>

-- Description:       老化柜负载保存（系统生成，禁止手工维护编码）

-- =============================================

CREATE PROCEDURE [dbo].[AgingCabinetLoadSaveData]

    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,

    @I_IsNewRow BIT = 0 OUTPUT,

    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,

    @I_LanguageId CHAR(1) = '1',

    @I_PlugInCommand VARCHAR(5) = '',

    @I_OrBitUserId CHAR(12) = '',

    @I_OrBitUserName NVARCHAR(100) = '',

    @I_ResourceId CHAR(12) = '',

    @I_ResourceName NVARCHAR(100) = '',

    @I_PKId CHAR(12) = '',

    @I_SourcePKId CHAR(12) = '',

    @I_ParentPKId CHAR(12) = '',

    @I_Parameter NVARCHAR(100) = '',

    @AgingCabinetLoadId CHAR(12) = '',

    @AssetDetailId CHAR(12) = '',

    @LoadSeq INT = 0,

    @LoadCode NVARCHAR(50) = '',

    @CreateDate DATETIME = NULL

AS

BEGIN

    BEGIN TRY

        SET NOCOUNT ON;

        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



        SET @I_ReturnMessage = N'ServerMessage:负载编码由系统在保存老化柜时自动生成，请勿手工维护';

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

            N'AgingCabinetLoadSaveData', N'SQL_EXCEPTION', N'CATCH', N'老化柜负载SaveData异常',

            @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId

        );



        SET @I_ReturnMessage = N'ServerMessage:' + @ErrMsg;

        RETURN -1;

    END CATCH

END

