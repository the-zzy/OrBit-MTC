
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
	-- This Stored Procedure is created by OrBit-MetaObject engine	
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	--执行TreeView,注意：以下过程必须根据业务的需求进行调整
	--如果您不了解TreeView过程如何编写，请参考我们提供的示例_SampleProjectTreeView

    DECLARE @TempPalletSN TABLE
        (
          PalletSN NVARCHAR(50) ,
          PalletCount INT ,
          BoxHeight DECIMAL(18, 3) ,
          BoxNetWeight DECIMAL(18, 2) ,
          BoxGrossWeight DECIMAL(18, 2)
        );

    DECLARE @L NVARCHAR(10) = '';
    DECLARE @W NVARCHAR(10) = '';
    DECLARE @H NVARCHAR(10) = '';

    DECLARE @ProductDescription NVARCHAR(500) = '';
	DECLARE @ProductName NVARCHAR(50) = '';
	DECLARE @NetWeight DECIMAL(18,2) = 0;

    IF @I_PlugInCommand = 'BMIS'
    BEGIN
        IF @I_ParentPKId <> ''
        BEGIN
            SELECT  a.KDPalletInfoId, a.PalletSN, b.BoxSn, a.CountQty, t.bindqty, t.qty, a.L, a.W, a.H, a.PNETWEIGHT,
                    a.PGROSSWEIGHT
            FROM    KDPalletInfo a
            LEFT JOIN dbo.CKDPackingBox b ON b.BrazilMatIssueId = a.KDOrderInfoId AND a.KDPalletInfoId = b.KDPalletInfoId
            LEFT JOIN (
                        SELECT  BrazilMatIssuedId, CKDBoxSN, COUNT(CKDBoxSN) AS bindqty, SUM(LotQty) AS qty
                        FROM    dbo.CKDPacking
                        WHERE   BrazilMatIssuedId = @I_ParentPKId
                        GROUP BY BrazilMatIssuedId, CKDBoxSN
                      ) AS t ON t.BrazilMatIssuedId = a.KDOrderInfoId AND t.CKDBoxSN = b.BoxSn
            WHERE   a.KDOrderInfoId = @I_ParentPKId AND a.IsCancel = 0
            ORDER BY PalletSN;
            RETURN 0;
        END;

        IF @I_PKId <> ''
        BEGIN
            SELECT  a.KDPalletInfoId, a.PalletSN, b.BoxSn, a.CountQty, t.bindqty, t.qty, a.L, a.W, a.H, a.PNETWEIGHT,
                    a.PGROSSWEIGHT
            FROM    KDPalletInfo a
            LEFT JOIN dbo.CKDPackingBox b ON b.BrazilMatIssueId = a.KDOrderInfoId AND a.KDPalletInfoId = b.KDPalletInfoId
            LEFT JOIN (
                        SELECT  BrazilMatIssuedId, CKDBoxSN, COUNT(CKDBoxSN) AS bindqty, SUM(LotQty) AS qty
                        FROM    dbo.CKDPacking
                        WHERE   BrazilMatIssuedId = @I_ParentPKId
                        GROUP BY BrazilMatIssuedId, CKDBoxSN
                      ) AS t ON t.BrazilMatIssuedId = a.KDOrderInfoId AND t.CKDBoxSN = b.BoxSn
            WHERE   a.KDOrderInfoId = @I_PKId AND a.IsCancel = 0
            ORDER BY PalletSN;
            RETURN 0;
        END;

        SELECT  a.KDPalletInfoId, a.PalletSN, b.BoxSn, a.CountQty, t.bindqty, t.qty, a.L, a.W, a.H, a.PNETWEIGHT,
                a.PGROSSWEIGHT
        FROM    KDPalletInfo a
        LEFT JOIN dbo.CKDPackingBox b ON b.BrazilMatIssueId = a.KDOrderInfoId AND a.KDPalletInfoId = b.KDPalletInfoId
        LEFT JOIN (
                    SELECT  BrazilMatIssuedId, CKDBoxSN, COUNT(CKDBoxSN) AS bindqty, SUM(LotQty) AS qty
                    FROM    dbo.CKDPacking
                    WHERE   BrazilMatIssuedId = @I_ParentPKId
                    GROUP BY BrazilMatIssuedId, CKDBoxSN
                  ) AS t ON t.BrazilMatIssuedId = a.KDOrderInfoId AND t.CKDBoxSN = b.BoxSn
        WHERE   a.IsCancel = 0
        ORDER BY PalletSN;
        RETURN 0;

    END;	
    ELSE
    BEGIN
        IF @I_ParentPKId <> ''  --当SaveData执行完成后刷新单行时执行
        BEGIN
			
            SELECT TOP 1
                    @ProductDescription = c.ProductDescription, @ProductName = c.prdname, @NetWeight = NetWeight
            FROM    dbo.KDMO a
            INNER JOIN dbo.MOItem b ON b.MOId = a.MOId
            INNER JOIN dbo.Product c ON c.ProductId = b.ProductId
            WHERE   KDOrderInfoId = @I_ParentPKId AND c.prdname LIKE '601%' AND CHARINDEX('栈板', c.ProductDescription) > 0;

			IF EXISTS ( SELECT 1 FROM dbo.Product WHERE prdname  = @ProductName AND ISNULL(NetWeight,0) = 0 )
			BEGIN
				EXEC [dbo].[Proc_CallWebServiceDoId]
					@I_ReturnMessage = N'' , -- nvarchar(max)
					@FactoryName = N'JB' , -- nvarchar(20)
					@parameter = @ProductName , -- varchar(20)
					@methodName = 'GetSapMaterial' -- varchar(100)

				SELECT @NetWeight = NetWeight
				FROM dbo.Product
				WHERE prdname = @ProductName
			END

            SET @ProductDescription = dbo.ConvertStrToClumn(@ProductDescription, '/', 2);
            SET @ProductDescription = REPLACE(@ProductDescription, 'MM', '');
			
            SELECT  @L = dbo.ConvertStrToClumn(@ProductDescription, '*', 1);
            SELECT  @W = dbo.ConvertStrToClumn(@ProductDescription, '*', 2);
            SELECT  @H = dbo.ConvertStrToClumn(@ProductDescription, '*', 3);

            INSERT  INTO @TempPalletSN ( PalletSN, PalletCount, BoxHeight, BoxNetWeight, BoxGrossWeight )
                    SELECT  a.PalletSN, COUNT(b.ShipPalletId), MAX(c.BoxHeight), SUM(c.NetWeight), SUM(c.GrossWeight)
                    FROM    dbo.KDPalletInfo a
                    INNER JOIN dbo.ShipPallet b ON b.PalletSN = a.PalletSN
                    INNER JOIN dbo.KDBoxInfo c ON c.BoxSN = b.BoxSN
                    WHERE   a.KDOrderInfoId = @I_ParentPKId AND b.IsCancel = 0 AND c.IsCancel = 0
                    GROUP BY a.PalletSN;

            SELECT  KDPalletInfo.KDPalletInfoId, KDPalletInfo.PalletSN, ShipPallet.BoxSN, ShipBox.LotSN,
            		ww.LotQty, p.prdname, p.ProductDescription, CountQty,
                    KDPalletInfo.PrintCount, CASE WHEN T1.PalletCount > 0 THEN 'Y'
                                                  ELSE ''
                                             END AS IsUsed,
											  --@L+'*'+@W+'*'+CAST(CAST(@H AS INT)+CAST((CountQty/4)*T1.BoxHeight AS INT) AS NVARCHAR(10))  AS Volume,
											 T1.BoxNetWeight AS '净重',
											  @NetWeight + 2 + T1.BoxGrossWeight AS '毛重',
											 
											 CASE WHEN KDPalletInfo.QCStatus = 0 THEN '未检验'
											 	WHEN KDPalletInfo.QCStatus = 1 THEN '检验OK'
											 	WHEN KDPalletInfo.QCStatus = 2 THEN '检验NG'
											 	ELSE '未检验' END AS QCStatus, KDPalletInfo.QCDefect
											 
            FROM    KDPalletInfo
            LEFT JOIN ShipPallet ON ShipPallet.PalletSN = KDPalletInfo.PalletSN AND ShipPallet.IsCancel = 0
            LEFT JOIN ShipBox ON ShipBox.BoxSN = ShipPallet.BoxSN AND ShipBox.IsCancel = 0
            LEFT JOIN @TempPalletSN AS T1 ON T1.PalletSN = KDPalletInfo.PalletSN
            LEFT JOIN WW_RMInventory ww ON ShipBox.LotSN = ww.LotSN
            LEFT JOIN Product p ON ww.ProductId = p.ProductId
            WHERE   KDPalletInfo.KDOrderInfoId = @I_ParentPKId AND KDPalletInfo.IsCancel = 0
            ORDER BY PalletSN;

            RETURN 0;
        END;

        IF @I_PKId <> ''  --当SaveData执行完成后刷新单行时执行
        BEGIN
			
            INSERT  INTO @TempPalletSN ( PalletSN )
                    SELECT  PalletSN
                    FROM    dbo.KDPalletInfo
                    WHERE   KDPalletInfoId = @I_PKId;

            SELECT  KDPalletInfo.KDPalletInfoId, KDPalletInfo.PalletSN, ShipPallet.BoxSN, ShipBox.LotSN, CountQty,
                    KDPalletInfo.PrintCount, CASE WHEN T1.PalletCount > 0 THEN 'Y'
                                                  ELSE ''
           END AS IsUsed
            FROM    KDPalletInfo
            LEFT JOIN ShipPallet ON ShipPallet.PalletSN = KDPalletInfo.PalletSN AND ShipPallet.IsCancel = 0
            LEFT JOIN ShipBox ON ShipBox.BoxSN = ShipPallet.BoxSN AND ShipBox.IsCancel = 0
            LEFT JOIN (
                        SELECT  COUNT(ShipPalletId) AS PalletCount, a.PalletSN
                        FROM    @TempPalletSN a
                        INNER JOIN dbo.ShipPallet b ON b.PalletSN = a.PalletSN
                        WHERE   b.IsCancel = 0
                        GROUP BY a.PalletSN
                      ) AS T1 ON T1.PalletSN = KDPalletInfo.PalletSN
            WHERE   KDPalletInfo.KDPalletInfoId = @I_PKId AND KDPalletInfo.IsCancel = 0;
            RETURN 0;
        END;
			
	--向前台返回所有的数据时执行
        RETURN 0;
    END;
END;


--SELECT * FROM vendor


