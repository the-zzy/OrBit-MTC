

-- =============================================

-- Author:            <1003153>

-- Create date:       <2026.10.26>

-- Description:       老化柜负载树（按资产明细父键过滤）

-- =============================================

CREATE PROCEDURE [dbo].[AgingCabinetLoadTreeView]

    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,

    @I_LanguageId CHAR(1) = '1',

    @I_PlugInCommand VARCHAR(5) = '',

    @I_FiltCondition NVARCHAR(MAX) = '',

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



        SELECT

            a.AgingCabinetLoadId,

            a.LoadCode AS TreeNodeText,

            a.LoadSeq

        FROM dbo.AgingCabinetLoad a WITH (NOLOCK)

        WHERE a.AssetDetailId = @I_ParentPKId AND a.IsCancel = 0

        ORDER BY a.LoadSeq;



        SET @I_ReturnMessage = N'ServerMessage:操作成功';

        RETURN 0;

    END TRY

    BEGIN CATCH

        DECLARE @ErrNum INT = ERROR_NUMBER();

        DECLARE @ErrLine INT = ERROR_LINE();

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();



        INSERT INTO dbo.SqlProcedureIssueLog (

            ProcName, IssueType, StepCode, Message, ErrNumber, ErrLine, ErrMessage, OrBitUserId

        )

        VALUES (

            N'AgingCabinetLoadTreeView', N'SQL_EXCEPTION', N'CATCH', N'老化柜负载TreeView异常',

            @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId

        );



        SET @I_ReturnMessage = N'ServerMessage:' + @ErrMsg;

        RETURN -1;

    END CATCH

END

