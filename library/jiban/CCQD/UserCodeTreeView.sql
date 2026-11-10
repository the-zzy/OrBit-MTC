-- =============================================

-- Author:		<OBit Team >

-- Create date: <2008.8.8>

-- Description:	<获取UserCode导航树>

-- Rev: 10.00

-- =============================================

CREATE PROCEDURE dbo.UserCodeTreeView

    @I_PlugInCommand VARCHAR(5) = '' ,			--插件命令

    @I_OrBitUserId CHAR(12) = '' ,				--用户ID

    @I_OrBitUserName NVARCHAR(100) = '' ,		--用户名

    @I_ResourceId CHAR(12) = '' ,			--资源ID(如果资源不在资源清单中，那么它将是空的)

    @I_ResourceName NVARCHAR(100) = '' ,		--资源名

    @I_FiltCondition NVARCHAR(MAX) = '' ,	--过滤条件表达式

    @I_PKId CHAR(12) = '' ,					--主键

    @I_ParentPKId CHAR(12) = '' ,				--用于过滤的上级主键

    @I_Parameter NVARCHAR(100) = ''			--插件参数

--以上变量为服务固定参数，必须在每一个TreeView过程中进行定义。>

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 



    DECLARE @IsAdmin BIT = 0;



    DECLARE @Divisionid VARCHAR(12)= '';



    SELECT  @Divisionid = DivisionId

    FROM    SysUser

    WHERE   UserId = @I_OrBitUserId; 



    PRINT @Divisionid;



    SELECT  @IsAdmin = IsAdmin

    FROM    dbo.SysUser

    WHERE   UserId = @I_OrBitUserId;



    IF @I_PKId <> ''

    BEGIN

        SELECT  UserCodeId, UserCodeName, UserCodeDescription

        FROM    dbo.UserCode

        WHERE   UserCodeId = @I_PKId;



        RETURN 0;

    END;



    IF @I_ParentPKId <> ''

    BEGIN

        SELECT  UserCodeId, UserCodeName, UserCodeDescription, Parameter1, Parameter2, Parameter3

        FROM    dbo.UserCode

        WHERE   ParentUserCodeId = @I_ParentPKId;



        RETURN 0;

    END;



    IF @IsAdmin = 1

    BEGIN

		

        SELECT  UserCodeId, UserCodeName, UserCodeDescription

        FROM    dbo.UserCode

        WHERE   ParentUserCodeId = '';



        RETURN 0;

    END;



    IF @Divisionid IN ( 'DIV10000000T', 'DIV10000000N', 'DIV100000015', 'DIV10000000P' ) AND @I_PlugInCommand <> 'CCQD'

    BEGIN

 

        IF @I_OrBitUserName IN ( 'CK1072' )

        BEGIN

            --SELECT  UserCodeId, UserCodeName, UserCodeDescription

            --FROM    UserCode

            --WHERE   ParentUserCodeId = 'URC1000000UH'

            --ORDER BY UserCodeName;



            SELECT  UserCodeId, UserCodeName, UserCodeDescription

            FROM    UserCode

            WHERE   ParentUserCodeId = 'URC1000000UH' OR UserCodeId = 'URC1000002X3'

            ORDER BY UserCodeName;







            RETURN 0;

        END;



        IF @I_OrBitUserName IN ( 'SC1905' )

        BEGIN

            SELECT  UserCodeId, UserCodeName, UserCodeDescription

            FROM    UserCode

            WHERE   UserCodeId = 'URC1000000M5'

            ORDER BY UserCodeName;



            RETURN 0;

        END;



        IF @I_OrBitUserName IN ( '1002950' )

        BEGIN

            SELECT  UserCodeId, UserCodeName, UserCodeDescription

            FROM    UserCode

            WHERE   ParentUserCodeId = ''

            ORDER BY UserCodeName;



            RETURN 0;

        END;

    END;





    IF @I_OrBitUserName = 'JBGCPE'

    BEGIN

		

        SELECT  a.UserCodeId, a.UserCodeName, a.UserCodeDescription

        FROM    dbo.UserCode a

        WHERE   a.ParentUserCodeId = '' AND a.UserCodeName = 'BinKeyName';

        RETURN 0; 

    END;  

    SELECT  a.UserCodeId, a.UserCodeName, a.UserCodeDescription

    FROM    dbo.UserCode a

    INNER JOIN dbo.Division b ON b.DivisionId = a.Divisionid

    WHERE   b.DivisionId = @Divisionid AND a.ParentUserCodeId = '';

		

    RETURN 0;



END;





