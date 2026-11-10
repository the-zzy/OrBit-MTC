

-- =============================================

-- Author:		<OrBit Team>

-- Create date: <2008.8.8>

-- Description:	<获取UserCode的主视图>

-- =============================================

CREATE PROCEDURE [dbo].[UserCodeMainView] @I_PKId CHAR(12) = ''					--主键>>

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



    SELECT  UserCodeName, UserCodeDescription, Parameter1, Parameter2, Parameter3, ParentUserCodeId

    FROM    dbo.UserCode

    WHERE   UserCodeId = @I_PKId;



    RETURN 0;

END;



