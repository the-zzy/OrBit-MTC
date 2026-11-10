

-- =============================================

-- Author:		<benson>

-- Create date: <07  6 2016  5:59PM>

-- Description:	为KDPalletInfo创建导航树视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDPalletInfoTreeView]

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



    IF @I_PKId <> ''  --当SaveData执行完成后刷新单行时执行

    BEGIN



        SELECT  a.KDPalletInfoId, a.PalletSN, a.CountQty, a.PrintCount

        FROM    dbo.KDPalletInfo a

        WHERE   a.KDPalletInfoId = @I_PKId;

        RETURN 0;

    END;



    IF @I_PlugInCommand = 'KDOI' AND @I_ParentPKId <> ''

    BEGIN

        SELECT  a.KDPalletInfoId, a.PalletSN, b.BoxSN, a.CountQty, a.Floors, a.PrintCount, a.PNetWeight, a.L, a.W, a.H,

                a.CreateDate

        FROM    dbo.KDPalletInfo a

        LEFT JOIN dbo.ShipPallet b ON b.PalletSN = a.PalletSN AND b.IsCancel = 0

        WHERE   a.KDOrderInfoId = @I_ParentPKId AND a.IsCancel = 0;



        RETURN 0;

    END;



    IF @I_ParentPKId <> ''  --当SaveData执行完成后刷新单行时执行

    BEGIN

		

        CREATE TABLE #TempPalletSN

            (

              PalletSN NVARCHAR(50) DEFAULT ''

            );



        CREATE TABLE #TempBoxSN

            (

              PalletSN NVARCHAR(50) DEFAULT '' ,

              BoxSN NVARCHAR(50) DEFAULT '' ,

              LotSN NVARCHAR(50) DEFAULT '' ,

              ProductName NVARCHAR(50) DEFAULT ''

            );





        INSERT  INTO #TempPalletSN ( PalletSN )

                SELECT  PalletSN

                FROM    dbo.KDPalletInfo

                WHERE   KDOrderInfoId = @I_ParentPKId AND IsCancel = 0;



        INSERT  INTO #TempBoxSN ( PalletSN, BoxSN, LotSN, ProductName )

                SELECT  a.PalletSN, b.BoxSN, c.LotSN, d.prdname AS ProductName

                FROM    #TempPalletSN a

                INNER JOIN dbo.ShipPallet b ON b.PalletSN = a.PalletSN

                INNER JOIN dbo.ShipBox c ON c.BoxSN = b.BoxSN

                INNER JOIN dbo.Product d ON d.ProductId = c.ProductId

                WHERE   b.IsCancel = 0 AND c.IsCancel = 0;



        SELECT  a.KDPalletInfoId, a.PalletSN, b.BoxSN, b.LotSN, b.ProductName, a.CountQty, a.Floors, a.PrintCount, a.L,

                a.W, a.H, a.PNetWeight

        FROM    dbo.KDPalletInfo a WITH ( NOLOCK )

        LEFT JOIN #TempBoxSN b ON b.PalletSN = a.PalletSN

        WHERE   a.KDOrderInfoId = @I_ParentPKId AND a.IsCancel = 0

        ORDER BY a.PalletSN;



        DROP TABLE #TempPalletSN;

        DROP TABLE #TempBoxSN;



        RETURN 0;

    END;



    RETURN 0;



END;







