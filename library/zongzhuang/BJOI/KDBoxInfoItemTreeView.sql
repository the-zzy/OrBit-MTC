

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016  1:55PM>

-- Description:	为KDBoxInfo创建导航树视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDBoxInfoItemTreeView]

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

	-- This Stored Procedure is created by OrBit-MetaObject engine	

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--执行TreeView,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解TreeView过程如何编写，请参考我们提供的示例_SampleProjectTreeView

	

    DECLARE @KDOrderInfoId CHAR(12)= '';

    DECLARE @BoxLevel NVARCHAR(30)= '';

    DECLARE @BoxType NVARCHAR(30)= '';



    CREATE TABLE #TempKDBoxInfo

        (

          KDBoxInfoId CHAR(12) DEFAULT '' ,

          BoxSN NVARCHAR(50) DEFAULT '' ,

          BoxNumber NVARCHAR(50) DEFAULT '' ,

          BoxLength DECIMAL(18, 2) DEFAULT 0 ,

          BoxWidth DECIMAL(18, 2) DEFAULT 0 ,

          BoxHeight DECIMAL(18, 2) DEFAULT 0 ,

          NetWeight DECIMAL(18, 2) DEFAULT 0 ,

          GrossWeight DECIMAL(18, 2) DEFAULT 0 ,

          IsPrint BIT DEFAULT 0 ,

          PrintCount INT DEFAULT 0 ,

          PCount INT DEFAULT 0 ,

          ShipPalletId CHAR(12) DEFAULT '',

		  DeliveryName VARCHAR(20) DEFAULT '',

		  ScanOperator VARCHAR(10) DEFAULT '',

		  Container VARCHAR(30) DEFAULT '',

		  IssuerDate DATETIME

        );



    CREATE TABLE #TempShipBox

        (

          KDBoxInfoId CHAR(12) DEFAULT '' ,

          BoxSN NVARCHAR(50) DEFAULT '' ,

          LotSN NVARCHAR(60) DEFAULT '' ,

          ProductId CHAR(12) DEFAULT '' ,

          OrderNo NVARCHAR(50) DEFAULT '' ,

          PackQty DECIMAL(18, 4) DEFAULT 0 ,

          ProductName NVARCHAR(50) DEFAULT ''

        );



    SELECT  @KDOrderInfoId = KDOrderInfoId, @BoxType = BoxType

    FROM    dbo.KDBoxInfo WITH ( NOLOCK )

    WHERE   KDBoxInfoId = @I_ParentPKId;



    INSERT  INTO #TempKDBoxInfo ( KDBoxInfoId, BoxSN, BoxNumber, BoxLength, BoxWidth, BoxHeight, NetWeight, GrossWeight,

                                  IsPrint, PrintCount, DeliveryName, ScanOperator, Container, IssuerDate )

            SELECT  a.KDBoxInfoId, a.BoxSN, a.BoxNumber, a.BoxLength, a.BoxWidth, a.BoxHeight, a.NetWeight,

                    a.GrossWeight, a.IsPrint, a.PrintCount, a.DeliveryName, a.ScanOperator, a.Container, a.IssuerDate

            FROM    dbo.KDBoxInfo a WITH ( NOLOCK )

            LEFT JOIN dbo.KDBoxItem b WITH ( NOLOCK ) ON b.KDBoxInfoId = a.KDBoxInfoId AND b.IsCancel = 0

            WHERE   a.KDOrderInfoId = @KDOrderInfoId AND a.BoxType = @BoxType AND a.IsCancel = 0

            ORDER BY a.BoxSN;



    INSERT  INTO #TempShipBox ( KDBoxInfoId, BoxSN, LotSN, ProductId )

            SELECT  a.KDBoxInfoId, a.BoxSN, b.LotSN, b.ProductId

            FROM    #TempKDBoxInfo a

            INNER JOIN dbo.ShipBox b ON b.BoxSN = a.BoxSN

            WHERE   b.IsCancel = 0;



    UPDATE  a

    SET     a.ProductName = b.prdname

    FROM    #TempShipBox a

    INNER JOIN dbo.Product b ON b.ProductId = a.ProductId;



    UPDATE  a

    SET     a.PackQty = b.LotQty, a.OrderNo = b.OrderNo

    FROM    #TempShipBox a

    INNER JOIN dbo.WW_RMInventory b ON b.LotSN = a.LotSN;



    UPDATE  a

    SET     a.PCount = b.PCount

    FROM    #TempKDBoxInfo a

    INNER JOIN (

                 SELECT KDBoxInfoId, COUNT(DISTINCT ProductId) AS PCount

                 FROM   #TempShipBox

                 GROUP BY KDBoxInfoId

               ) b ON b.KDBoxInfoId = a.KDBoxInfoId;



    UPDATE  a

    SET     a.ShipPalletId = b.ShipPalletId

    FROM    #TempKDBoxInfo a

    INNER JOIN dbo.ShipPallet b ON b.BoxSN = a.BoxSN

    WHERE   b.IsCancel = 0;



    SELECT  DISTINCT a.KDBoxInfoId, a.BoxSN, a.BoxNumber, b.LotSN, b.ProductName, b.PackQty, a.PCount,

            IIF(a.ShipPalletId <> '', 'Y', '') AS IsPallet, a.BoxLength, a.BoxWidth, a.BoxHeight, a.NetWeight,

            a.GrossWeight, a.IsPrint, a.PrintCount, a.DeliveryName, a.Container, a.ScanOperator, a.IssuerDate

    FROM    #TempKDBoxInfo a

    LEFT JOIN #TempShipBox b ON b.BoxSN = a.BoxSN

	ORDER BY a.BoxSN;



    DROP TABLE #TempKDBoxInfo;

    DROP TABLE #TempShipBox;



    RETURN 0;



END;







