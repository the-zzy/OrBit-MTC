--**==================================================------

--****************************************************------

--**注意:元对象 Old存储过程将被覆盖，存储过程更新包括 ViewList过程的更新

--****************************************************------

--**==================================================------



-- =============================================

-- Author:            <1003153>

-- Create date:       <2026.10.26>

-- Description:       老化柜负载子元对象 CRUD（负载由保存老化柜时自动生成，界面只读）

-- =============================================

-- [元字段三一致] AgingCabinetLoadId, AssetDetailId, LoadSeq, LoadCode, CreateDate

-- =============================================

CREATE PROCEDURE [dbo].[AgingCabinetLoadMainView]

    @I_PKId CHAR(12) = ''

AS

BEGIN

    BEGIN TRY

        SET NOCOUNT ON;

        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



        SELECT

            a.AgingCabinetLoadId,

            a.AssetDetailId,

            a.LoadSeq,

            a.LoadCode,

            a.CreateDate

        FROM dbo.AgingCabinetLoad a WITH (NOLOCK)

        WHERE a.AgingCabinetLoadId = @I_PKId AND a.IsCancel = 0;



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

            N'AgingCabinetLoadMainView', N'SQL_EXCEPTION', N'CATCH', N'老化柜负载MainView异常',

            @ErrNum, @ErrLine, @ErrMsg, N''

        );



        RETURN -1;

    END CATCH

END

