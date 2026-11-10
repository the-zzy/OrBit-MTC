









-- =============================================

-- Author:		<OBit Team >

-- Create date: <2008.8.8>

-- Description:	<获取BOMRoot导航树>

-- Rev: 10.00

-- =============================================

CREATE PROCEDURE [dbo].[BOMRootTreeView]

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

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



    IF @I_PKId <> ''

    BEGIN



        SELECT  DefaultBOMId AS BOMId, BOMRootId, [dbo].[RemoveZero](BOMName) AS BOMName

        FROM    dbo.BOMRoot

        WHERE   ( DefaultBOMId = @I_PKId )

        ORDER BY BOMName;

        RETURN 0;

    END;



	----清理孤儿数据

	--if exists(select top 1  BOMId from BOM where BOMRootId not in (select BOMRootId from BOMRoot))

	--begin

	--	begin tran

	--		delete  from BOM where BOMRootId not in (select BOMRootId from BOMRoot)

	--	commit tran

	--end

        

/*	IF @I_PlugInCommand = 'BOMD'

	BEGIN

		SELECT  DefaultBOMId AS BOMId, BOMRootId, BOMName AS BOMName

	    FROM    dbo.BOMRoot

	    WHERE   Type = '0'

	    AND LEFT(BOMName, 1) = '5'

	    --AND ( LEFT(RIGHT(BOMName, 3), 1) = 'M' OR  LEFT(RIGHT(BOMName, 4), 1) = 'M')

	    ORDER BY BOMName;

	

	

	    RETURN 0;

	END*/

	





    SELECT  DefaultBOMId AS BOMId, BOMRootId, BOMName AS BOMName

    FROM    dbo.BOMRoot

    WHERE   Type = '0'

    ORDER BY BOMName;

    RETURN 0;



END;













