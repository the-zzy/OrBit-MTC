
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016  1:55PM>
-- Description:	为KDBoxInfo创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDBoxInfoItemProDoMethod]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKid CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = ''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
AS
BEGIN
	-- This Stored Procedure is created by OrBit-MetaObject engine	
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	--执行TreeView,注意：以下过程必须根据业务的需求进行调整
	--如果您不了解TreeView过程如何编写，请参考我们提供的示例_SampleProjectTreeView
	
    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @BoxLevel NVARCHAR(30);
    DECLARE @BoxType NVARCHAR(30);

    SET @KDOrderInfoId = '';
    SET @BoxLevel = '';
    SET @BoxType = '';

    IF @I_Sender = 'ExportKDBoxInfoItemPro'
    BEGIN
    
        SELECT  @KDOrderInfoId = KDOrderInfoId, @BoxLevel = BoxLevel, @BoxType = BoxType
        FROM    KDBoxInfo
        WHERE   KDBoxInfoId = @I_ParentPKId;

        SELECT  KDBoxInfo.KDBoxInfoId, KDBoxInfo.KDOrderInfoId, KDBoxInfo.BoxSN, KDBoxInfo.BoxNumber,
                [dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, KDBoxItem.ModuleName,
                CONVERT(INT, KDBoxItem.RealQty) AS PackQty, KDBoxInfo.BoxLength, KDBoxInfo.BoxWidth, KDBoxInfo.BoxHeight,
                KDBoxInfo.NetWeight, KDBoxInfo.GrossWeight, KDBoxInfo.IsPrint, KDBoxInfo.PrintCount
        INTO    #KDBoxtemp
        FROM    KDBoxInfo
        LEFT JOIN KDBoxItem ON KDBoxInfo.KDBoxInfoId = KDBoxItem.KDBoxInfoId
        LEFT JOIN Product ON Product.ProductId = KDBoxItem.ProductId
        LEFT JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
        WHERE   KDBoxInfo.KDOrderInfoId = @KDOrderInfoId AND KDBoxInfo.BoxLevel = @BoxLevel AND KDBoxInfo.BoxType = @BoxType AND KDBoxInfo.IsCancel = 0
        ORDER BY KDBoxInfo.BoxSN;

	
        SELECT  ISNULL(COUNT(DISTINCT b.LotId), 0) AS PackQty, b.LotSN, b.BoxSN
        INTO    #Shipboxtemp
        FROM    #KDBoxtemp a
        LEFT JOIN ShipBox b ON a.BoxSN = b.BoxSN
        WHERE   b.IsCancel = 0
        GROUP BY b.BoxSN, b.LotSN;

	
        SELECT  ISNULL(COUNT(DISTINCT ProductId), 0) AS PCount, KDBoxInfoId
        INTO    #BoxItemtemp
        FROM    KDBoxItem
        WHERE   KDOrderInfoId = @KDOrderInfoId AND IsCancel = 0
        GROUP BY KDBoxInfoId;

        SELECT  ShipPalletId, a.BoxSN
        INTO    #Pallettemp
        FROM    #KDBoxtemp a
        LEFT JOIN ShipPallet b ON a.BoxSN = b.BoxSN
        WHERE   b.IsCancel = 0; 


        SELECT
			DISTINCT
                e.OrderName, a.BoxSN, a.BoxNumber, a.ProductName, a.ModuleName, a.PackQty, c.PCount,
                CASE WHEN d.ShipPalletId <> '' THEN 'Y'
                     ELSE ''
                END AS IsPallet, a.BoxLength, a.BoxWidth, a.BoxHeight, a.NetWeight, a.GrossWeight, a.IsPrint,
                a.PrintCount
        FROM    #KDBoxtemp a --	left join #Shipboxtemp b on a.BoxSN=b.BoxSN
        LEFT JOIN #BoxItemtemp c ON a.KDBoxInfoId = c.KDBoxInfoId
        LEFT JOIN #Pallettemp d ON a.BoxSN = d.BoxSN
        LEFT JOIN dbo.KDOrderInfo e ON a.KDOrderInfoId = e.KDOrderInfoId
        ORDER BY a.BoxSN;

        DROP TABLE #KDBoxtemp,
		#Shipboxtemp, 
		#BoxItemtemp,
		#Pallettemp;


        RETURN 0;
    END; 

 IF @I_Sender = 'ExportKDBoxInfoItem'
    BEGIN

        SELECT  @KDOrderInfoId = KDOrderInfoId, @BoxLevel = BoxLevel, @BoxType = BoxType
        FROM    KDBoxInfo
        WHERE   KDBoxInfoId = @I_ParentPKId;

        SELECT  KDBoxInfo.KDBoxInfoId, KDBoxInfo.KDOrderInfoId, KDBoxInfo.BoxSN, KDBoxInfo.BoxNumber, KDBoxInfo.BoxLength, KDBoxInfo.BoxWidth,
                KDBoxInfo.BoxHeight, KDBoxInfo.NetWeight, KDBoxInfo.GrossWeight, KDBoxInfo.IsPrint, KDBoxInfo.PrintCount
        INTO    #KDBoxtemp2
        FROM    KDBoxInfo
        LEFT JOIN KDBoxItem ON KDBoxInfo.KDBoxInfoId = KDBoxItem.KDBoxInfoId
        WHERE   KDBoxInfo.KDOrderInfoId = @KDOrderInfoId AND KDBoxInfo.BoxLevel = @BoxLevel AND KDBoxInfo.BoxType = @BoxType AND KDBoxInfo.IsCancel = 0
        ORDER BY KDBoxInfo.BoxSN;

	
        SELECT  ISNULL(COUNT(DISTINCT b.LotSN), 0) AS PackQty, b.LotSN, b.BoxSN, MAX(b.CreateDate) AS CreateDate
        INTO    #Shipboxtemp2
        FROM    #KDBoxtemp2 a
        LEFT JOIN ShipBox b ON a.BoxSN = b.BoxSN
        WHERE   b.IsCancel = 0
        GROUP BY b.BoxSN, b.LotSN;

	
        SELECT  ISNULL(COUNT(DISTINCT ProductId), 0) AS PCount, KDBoxInfoId
        INTO    #BoxItemtemp2
        FROM    KDBoxItem
        WHERE   KDOrderInfoId = @KDOrderInfoId AND IsCancel = 0
        GROUP BY KDBoxInfoId;

        SELECT  ShipPalletId, a.BoxSN
        INTO    #Pallettemp2
        FROM    #KDBoxtemp2 a
        LEFT JOIN ShipPallet b ON a.BoxSN = b.BoxSN
        WHERE   b.IsCancel = 0; 


        SELECT
		DISTINCT
                e.OrderName, a.BoxSN, a.BoxNumber, b.LotSN, b.PackQty, c.PCount,
                CASE WHEN d.ShipPalletId <> '' THEN 'Y'
                     ELSE ''
                END AS IsPallet, a.BoxLength, a.BoxWidth, a.BoxHeight, a.NetWeight, a.GrossWeight, a.IsPrint,
                a.PrintCount, b.CreateDate
        FROM    #KDBoxtemp2 a
        LEFT JOIN #Shipboxtemp2 b ON a.BoxSN = b.BoxSN
        LEFT JOIN #BoxItemtemp2 c ON a.KDBoxInfoId = c.KDBoxInfoId
        LEFT JOIN #Pallettemp2 d ON a.BoxSN = d.BoxSN
		LEFT JOIN dbo.KDOrderInfo e ON e.KDOrderInfoId = a.KDOrderInfoId
        ORDER BY a.BoxSN;

        DROP TABLE #KDBoxtemp2,
		#Shipboxtemp2, 
		#BoxItemtemp2,
		#Pallettemp2;

        RETURN 0;
    END;

    RETURN 0;
END;

