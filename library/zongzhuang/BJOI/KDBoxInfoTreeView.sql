

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016  1:55PM>

-- Description:	为KDBoxInfo创建导航树视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDBoxInfoTreeView]

    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言

    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID

    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令

    @I_FiltCondition NVARCHAR(MAX) = '' ,	--过滤条件表达式

    @I_OrBitUserId CHAR(12) = '' ,			--用户ID

    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名

    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)

    @I_ResourceName NVARCHAR(100) = '' ,	--资源名

    @I_PKId CHAR(12) = '' ,				--主键

    @I_ParentPKId CHAR(12) = '' ,			--父级主键

    @I_Parameter NVARCHAR(100) = ''		--插件参数

--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.

AS

BEGIN



    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



	DECLARE @StartBoxSN NVARCHAR(50) = '';

	DECLARE @EndBoxSN NVARCHAR(50) = '';



    DECLARE @TempBox TABLE

        (

          BoxLevel NVARCHAR(20) ,

          BoxType NVARCHAR(20) ,

          KDBoxInfoId CHAR(12) ,

		  MINBoxSN NVARCHAR(50) ,

		  MAXBoxSN NVARCHAR(50) ,

          StartBoxSN NVARCHAR(50) ,

          EndBoxSN NVARCHAR(50) ,

          BoxQty INT

        );



    INSERT  INTO @TempBox ( BoxLevel, BoxType, KDBoxInfoId, BoxQty, MINBoxSN, MAXBoxSN )

            SELECT  BoxLevel, BoxType, MIN(KDBoxInfoId) AS KDBoxInfoId, COUNT(KDBoxInfoId), MIN(BoxSN),

                    MAX(BoxSN)

            FROM    dbo.KDBoxInfo

            WHERE   KDOrderInfoId = @I_ParentPKId AND IsCancel = 0

            GROUP BY BoxLevel, BoxType;



	UPDATE a 

	SET a.StartBoxSN = b.BoxNumber

	FROM @TempBox a

	INNER JOIN dbo.KDBoxInfo b ON b.BoxSN = a.MINBoxSN

	WHERE b.IsCancel = 0



	UPDATE a 

	SET a.EndBoxSN = b.BoxNumber

	FROM @TempBox a

	INNER JOIN dbo.KDBoxInfo b ON b.BoxSN = MAXBoxSN



    SELECT  a.KDBoxInfoId, a.BoxLevel, a.BoxType, b.BoxTypeDesc, a.BoxQty, a.StartBoxSN, a.EndBoxSN

    FROM    @TempBox a

    LEFT JOIN dbo.KDBoxType b ON b.BoxType = a.BoxType;



    RETURN 0;



END;





