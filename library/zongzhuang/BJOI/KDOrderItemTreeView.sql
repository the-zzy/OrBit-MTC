

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016  1:09PM>

-- Description:	为KDOrderModuleItem创建导航树视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDOrderItemTreeView]

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



	--SELECT   

	--	TA.KDOrderItemId,

	--	TA.ProductId,	

	--	TA.ModuleName,	

	--	TA.CustomerNumber,

	--	TA.EnglishDescription,

	--	IIF(TA.Isvalidity=1,'√','') AS Isvalidity,	

	--	[dbo].[RemoveZero](ProductRoot.ProductName) as ProductName,

	--	Product.ProductDescription,

	--	UOM.UOMName,

	--	Convert(float,TA.BOMQtyRequired) as BOMQtyRequired,

	--	Convert(float,TA.QtyPack) as QtyPack,

	--	Convert(float,TA.ItemQtyRequired) as ItemQtyRequired,

	--	Convert(float,ISNULL(T2.IsPackQty,0)) as IsPackQty,

	--	Convert(float,ISNULL(T3.IsInStorageQty,0)) as IsInStorageQty,

	--	Convert(float,ISNULL(T4.IsOutStorageQty,0)) as IsOutStorageQty,

	--	SysUser1.UserName as OQCAffirmUserName,

	--	CASE TA.OQCAffirmResult when '1' then '合格' when '2' then '不合格' else '' end as OQCAffirmResult, 

	--	TA.OQCAffirmDate,

	--	SysUser2.UserName as OQAAffirmUserName,

	--	CASE TA.OQAAffirmResult when '1' then '合格' when '2' then '不合格' else '' end as OQAAffirmResult, 

	--	TA.OQAAffirmDate,

	--	case

	--		when ISNULL(TA.IsIgnore,0)=1 then '[RowColor:X3]'

	--		when ISNULL(T2.IsPackQty,0)<ISNULL(Convert(float,TA.ItemQtyRequired),0) then '[ItemQtyRequired:Y4]'

	--		when ISNULL(T2.IsPackQty,0)>=ISNULL(Convert(float,TA.ItemQtyRequired),0) then '[ItemQtyRequired:YD]'	

	--		else ''  end as ColorControlId

	--FROM   KDOrderItem TA

	--inner join KDOrderInfo on KDOrderInfo.KDOrderInfoId=TA.KDOrderInfoId

	--inner join Product on Product.ProductId=TA.ProductId

	--inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId

	--left join UOM on UOM.UOMId=TA.UOMId

	--LEFT OUTER JOIN (SELECT SUM(ISNULL(RealQty, 0)) AS IsPackQty,KDBoxItem.KDOrderInfoId,KDBoxItem.ModuleName,KDBoxItem.ProductId

	--	FROM  KDBoxItem

	--	inner join KDBoxInfo on KDBoxInfo.KDBoxInfoId=KDBoxItem.KDBoxInfoId and KDBoxInfo.IsBox=0 and KDBoxInfo.IsCancel=0 and KDBoxItem.IsCancel=0

	--	 GROUP BY KDBoxItem.KDOrderInfoId,KDBoxItem.ModuleName,KDBoxItem.ProductId) AS T2 ON T2.KDOrderInfoId = TA.KDOrderInfoId 

	--	and T2.ModuleName=TA.ModuleName and T2.ProductId=TA.ProductId

	--LEFT OUTER JOIN (SELECT SUM(KDBoxItem.RealQty) as IsInStorageQty,KDPalletInfo.KDOrderInfoId,KDBoxItem.ProductId

	--	FROM KDPalletInfo

	--	inner join ShipPallet on ShipPallet.PalletSN=KDPalletInfo.PalletSN and ShipPallet.IsCancel=0

	--	inner join KDBoxInfo on KDBoxInfo.BoxSN=ShipPallet.BoxSN and KDBoxInfo.IsCancel=0 and IsBox=0

	--	inner join KDBoxItem on KDBoxItem.KDBoxInfoId=KDBoxInfo.KDBoxInfoId  and KDBoxItem.IsCancel=0 

	--	WHERE KDPalletInfo.StorageStatus in ('1','2')

	--	GROUP BY KDPalletInfo.KDOrderInfoId,KDBoxItem.ProductId) AS T3 ON T3.KDOrderInfoId=TA.KDOrderInfoId and T3.ProductId=TA.ProductId

	--LEFT OUTER JOIN (SELECT SUM(KDBoxItem.RealQty) as IsOutStorageQty,KDPalletInfo.KDOrderInfoId,KDBoxItem.ProductId

	--	FROM KDPalletInfo

	--	inner join ShipPallet on ShipPallet.PalletSN=KDPalletInfo.PalletSN and ShipPallet.IsCancel=0

	--	inner join KDBoxInfo on KDBoxInfo.BoxSN=ShipPallet.BoxSN and KDBoxInfo.IsCancel=0 and IsBox=0

	--	inner join KDBoxItem on KDBoxItem.KDBoxInfoId=KDBoxInfo.KDBoxInfoId  and KDBoxItem.IsCancel=0

	--	WHERE KDPalletInfo.StorageStatus='2'

	--	GROUP BY KDPalletInfo.KDOrderInfoId,KDBoxItem.ProductId) AS T4 ON T4.KDOrderInfoId=TA.KDOrderInfoId and T4.ProductId=TA.ProductId

	--left join SysUser SysUser1 on SysUser1.UserId=TA.OQCAffirmUserId

	--left join SysUser SysUser2 on SysUser2.UserId=TA.OQAAffirmUserId

	--where TA.KDOrderInfoId=@I_ParentPKId and TA.IsIgnore=0

	--order by IsIgnore,ModuleName





	if @I_PKId<>''  --当SaveData执行完成后刷新单行时执行

	begin

		SELECT  TA.KDOrderItemId, TA.KDOrderInfoId, TA.ProductId, TA.ModuleName, TA.CustomerNumber, TA.EnglishDescription,

            TA.FieldsA, ProductRoot.ProductWeight, IIF(TA.IsValidity = 1, '√', '') AS Isvalidity,

            [dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, Product.ProductDescription, UOM.UOMName,

            CONVERT(FLOAT, TA.BOMQtyRequired) AS BOMQtyRequired,

            CASE WHEN ISNULL(CONVERT(FLOAT, TA.QtyPack), 0) = 0 THEN CONVERT(FLOAT, TA.ItemQtyRequired)

                 ELSE ISNULL(CONVERT(FLOAT, TA.QtyPack), 0)

            END AS QtyPack, CONVERT(FLOAT, TA.ItemQtyRequired) AS ItemQtyRequired,

            CONVERT(FLOAT, TA.SingleWeight) AS SingleWeight, SysUser1.UserName AS OQCAffirmUserName,

            CASE TA.OQCAffirmResult

              WHEN '1' THEN '合格'

              WHEN '2' THEN '不合格'

              ELSE ''

            END AS OQCAffirmResult, TA.OQCAffirmDate, SysUser2.UserName AS OQAAffirmUserName, CASE TA.OQAAffirmResult

                                                                                                WHEN '1' THEN '合格'

                                                                                                WHEN '2' THEN '不合格'

                                                                                                ELSE ''

                                                                                              END AS OQAAffirmResult,

            TA.OQAAffirmDate, TA.IsIgnore,TA.LineSequence

    INTO    #KDOrderItem1

    FROM    KDOrderItem TA

    INNER JOIN KDOrderInfo ON KDOrderInfo.KDOrderInfoId = TA.KDOrderInfoId

    INNER JOIN Product ON Product.ProductId = TA.ProductId

    INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId

    LEFT JOIN UOM ON UOM.UOMId = TA.UOMId

    LEFT JOIN SysUser SysUser1 ON SysUser1.UserId = TA.OQCAffirmUserId

    LEFT JOIN SysUser SysUser2 ON SysUser2.UserId = TA.OQAAffirmUserId

    WHERE    TA.KDOrderItemId=@I_PKId AND TA.IsIgnore = 0

    ORDER BY IsIgnore, ModuleName;



	

    SELECT  ISNULL(SUM(RealQty), 0) AS IsPackQty, KDBoxItem.KDOrderInfoId, KDBoxItem.ModuleName, KDBoxItem.ProductId

    INTO    #T21

    FROM    KDBoxItem

    INNER JOIN KDBoxInfo ON KDBoxInfo.KDBoxInfoId = KDBoxItem.KDBoxInfoId AND KDBoxInfo.IsCancel = 0 AND KDBoxItem.IsCancel = 0 -- and KDBoxInfo.IsBox=0 

    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId

    GROUP BY KDBoxItem.KDOrderInfoId, KDBoxItem.ModuleName, KDBoxItem.ProductId;

	



    SELECT  ISNULL(SUM(KDBoxItem.RealQty), 0) AS IsInStorageQty, KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId

    INTO    #T31

    FROM    KDPalletInfo

    INNER JOIN ShipPallet ON ShipPallet.PalletSN = KDPalletInfo.PalletSN AND ShipPallet.IsCancel = 0

    INNER JOIN KDBoxInfo ON KDBoxInfo.BoxSN = ShipPallet.BoxSN AND KDBoxInfo.IsCancel = 0 AND IsBox = 0

    INNER JOIN KDBoxItem ON KDBoxItem.KDBoxInfoId = KDBoxInfo.KDBoxInfoId AND KDBoxItem.IsCancel = 0

    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId AND KDPalletInfo.StorageStatus IN ( '1', '2' )

    GROUP BY KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId;



    SELECT  ISNULL(SUM(KDBoxItem.RealQty), 0) AS IsOutStorageQty, KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId

    INTO    #T41

    FROM    KDPalletInfo

    INNER JOIN ShipPallet ON ShipPallet.PalletSN = KDPalletInfo.PalletSN AND ShipPallet.IsCancel = 0

    INNER JOIN KDBoxInfo ON KDBoxInfo.BoxSN = ShipPallet.BoxSN AND KDBoxInfo.IsCancel = 0 AND IsBox = 0

    INNER JOIN KDBoxItem ON KDBoxItem.KDBoxInfoId = KDBoxInfo.KDBoxInfoId AND KDBoxItem.IsCancel = 0

    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId AND KDPalletInfo.StorageStatus = '2'

    GROUP BY KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId;



    SELECT  TA.KDOrderItemId,TA.LineSequence, TA.ProductId, TA.ModuleName, TA.CustomerNumber, TA.EnglishDescription, TA.Isvalidity,

            TA.ProductName, TA.ProductDescription, TA.FieldsA, TA.ProductWeight, TA.UOMName,

            CONVERT(FLOAT, TA.BOMQtyRequired) AS BOMQtyRequired, CONVERT(FLOAT, TA.QtyPack) AS QtyPack,

            CONVERT(FLOAT, TA.ItemQtyRequired) AS ItemQtyRequired, TA.SingleWeight,

            CONVERT(FLOAT, ISNULL(T2.IsPackQty, 0)) AS IsPackQty,

            CONVERT(FLOAT, ISNULL(T3.IsInStorageQty, 0)) AS IsInStorageQty,

            CONVERT(FLOAT, ISNULL(T4.IsOutStorageQty, 0)) AS IsOutStorageQty, TA.OQCAffirmUserName, TA.OQCAffirmResult,

            TA.OQCAffirmDate, TA.OQAAffirmUserName, TA.OQAAffirmResult, TA.OQAAffirmDate,

            CASE WHEN ISNULL(TA.IsIgnore, 0) = 1 THEN '[RowColor:X3]'

                 WHEN ISNULL(T2.IsPackQty, 0) < ISNULL(CONVERT(FLOAT, TA.ItemQtyRequired), 0)

                 THEN '[ItemQtyRequired:Y4]'

                 WHEN ISNULL(T2.IsPackQty, 0) >= ISNULL(CONVERT(FLOAT, TA.ItemQtyRequired), 0)

                 THEN '[ItemQtyRequired:YD]'

                 ELSE ''

            END AS ColorControlId

    FROM    #KDOrderItem1 TA

    LEFT JOIN #T21 T2 ON T2.KDOrderInfoId = TA.KDOrderInfoId AND T2.ModuleName = TA.ModuleName AND T2.ProductId = TA.ProductId

    LEFT JOIN #T31 T3 ON T3.KDOrderInfoId = TA.KDOrderInfoId AND T3.ProductId = TA.ProductId

    LEFT JOIN #T41 T4 ON T4.KDOrderInfoId = TA.KDOrderInfoId AND T4.ProductId = TA.ProductId

    ORDER BY TA.IsIgnore, TA.ModuleName;



	   DROP TABLE #KDOrderItem1,#T21,#T31,#T41;

			return 0

	end



    SELECT  TA.KDOrderItemId, TA.KDOrderInfoId, TA.ProductId, TA.ModuleName, TA.CustomerNumber, TA.EnglishDescription,

            TA.FieldsA, ProductRoot.ProductWeight, IIF(TA.IsValidity = 1, '√', '') AS Isvalidity,

            [dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, Product.ProductDescription, UOM.UOMName,

            CONVERT(FLOAT, TA.BOMQtyRequired) AS BOMQtyRequired,

            CASE WHEN ISNULL(CONVERT(FLOAT, TA.QtyPack), 0) = 0 THEN CONVERT(FLOAT, TA.ItemQtyRequired)

                 ELSE ISNULL(CONVERT(FLOAT, TA.QtyPack), 0)

            END AS QtyPack, CONVERT(FLOAT, TA.ItemQtyRequired) AS ItemQtyRequired,

            CONVERT(FLOAT, TA.SingleWeight) AS SingleWeight, SysUser1.UserName AS OQCAffirmUserName,

            CASE TA.OQCAffirmResult

              WHEN '1' THEN '合格'

              WHEN '2' THEN '不合格'

              ELSE ''

            END AS OQCAffirmResult, TA.OQCAffirmDate, SysUser2.UserName AS OQAAffirmUserName, CASE TA.OQAAffirmResult

                                                                                                WHEN '1' THEN '合格'

                                                                                                WHEN '2' THEN '不合格'

                                                                                                ELSE ''

                                                                                              END AS OQAAffirmResult,

            TA.OQAAffirmDate, TA.IsIgnore,TA.LineSequence

    INTO    #KDOrderItem

    FROM    KDOrderItem TA

    INNER JOIN KDOrderInfo ON KDOrderInfo.KDOrderInfoId = TA.KDOrderInfoId

    INNER JOIN Product ON Product.ProductId = TA.ProductId

    INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId

    LEFT JOIN UOM ON UOM.UOMId = TA.UOMId

    LEFT JOIN SysUser SysUser1 ON SysUser1.UserId = TA.OQCAffirmUserId

    LEFT JOIN SysUser SysUser2 ON SysUser2.UserId = TA.OQAAffirmUserId

    WHERE   TA.KDOrderInfoId = @I_ParentPKId AND TA.IsIgnore = 0

    ORDER BY IsIgnore, ModuleName;



	

    SELECT  ISNULL(SUM(RealQty), 0) AS IsPackQty, KDBoxItem.KDOrderInfoId, KDBoxItem.ModuleName, KDBoxItem.ProductId

    INTO    #T2

    FROM    KDBoxItem

    INNER JOIN KDBoxInfo ON KDBoxInfo.KDBoxInfoId = KDBoxItem.KDBoxInfoId AND KDBoxInfo.IsCancel = 0 AND KDBoxItem.IsCancel = 0 -- and KDBoxInfo.IsBox=0 

    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId

    GROUP BY KDBoxItem.KDOrderInfoId, KDBoxItem.ModuleName, KDBoxItem.ProductId;

	



    SELECT  ISNULL(SUM(KDBoxItem.RealQty), 0) AS IsInStorageQty, KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId

    INTO    #T3

    FROM    KDPalletInfo

    INNER JOIN ShipPallet ON ShipPallet.PalletSN = KDPalletInfo.PalletSN AND ShipPallet.IsCancel = 0

    INNER JOIN KDBoxInfo ON KDBoxInfo.BoxSN = ShipPallet.BoxSN AND KDBoxInfo.IsCancel = 0 AND IsBox = 0

    INNER JOIN KDBoxItem ON KDBoxItem.KDBoxInfoId = KDBoxInfo.KDBoxInfoId AND KDBoxItem.IsCancel = 0

    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId AND KDPalletInfo.StorageStatus IN ( '1', '2' )

    GROUP BY KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId;



    SELECT  ISNULL(SUM(KDBoxItem.RealQty), 0) AS IsOutStorageQty, KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId

    INTO    #T4

    FROM    KDPalletInfo

    INNER JOIN ShipPallet ON ShipPallet.PalletSN = KDPalletInfo.PalletSN AND ShipPallet.IsCancel = 0

    INNER JOIN KDBoxInfo ON KDBoxInfo.BoxSN = ShipPallet.BoxSN AND KDBoxInfo.IsCancel = 0 AND IsBox = 0

    INNER JOIN KDBoxItem ON KDBoxItem.KDBoxInfoId = KDBoxInfo.KDBoxInfoId AND KDBoxItem.IsCancel = 0

    WHERE   KDBoxInfo.KDOrderInfoId = @I_ParentPKId AND KDPalletInfo.StorageStatus = '2'

    GROUP BY KDPalletInfo.KDOrderInfoId, KDBoxItem.ProductId;



    SELECT  TA.KDOrderItemId,TA.LineSequence, TA.ProductId, TA.ModuleName, TA.CustomerNumber, TA.EnglishDescription, TA.Isvalidity,

            TA.ProductName, TA.ProductDescription, TA.FieldsA, TA.ProductWeight, TA.UOMName,

            CONVERT(FLOAT, TA.BOMQtyRequired) AS BOMQtyRequired, CONVERT(FLOAT, TA.QtyPack) AS QtyPack,

            CONVERT(FLOAT, TA.ItemQtyRequired) AS ItemQtyRequired, TA.SingleWeight,

            CONVERT(FLOAT, ISNULL(T2.IsPackQty, 0)) AS IsPackQty,

            CONVERT(FLOAT, ISNULL(T3.IsInStorageQty, 0)) AS IsInStorageQty,

            CONVERT(FLOAT, ISNULL(T4.IsOutStorageQty, 0)) AS IsOutStorageQty, TA.OQCAffirmUserName, TA.OQCAffirmResult,

            TA.OQCAffirmDate, TA.OQAAffirmUserName, TA.OQAAffirmResult, TA.OQAAffirmDate,

            CASE WHEN ISNULL(TA.IsIgnore, 0) = 1 THEN '[RowColor:X3]'

                 WHEN ISNULL(T2.IsPackQty, 0) < ISNULL(CONVERT(FLOAT, TA.ItemQtyRequired), 0)

                 THEN '[ItemQtyRequired:Y4]'

                 WHEN ISNULL(T2.IsPackQty, 0) >= ISNULL(CONVERT(FLOAT, TA.ItemQtyRequired), 0)

                 THEN '[ItemQtyRequired:YD]'

                 ELSE ''

            END AS ColorControlId

    FROM    #KDOrderItem TA

    LEFT JOIN #T2 T2 ON T2.KDOrderInfoId = TA.KDOrderInfoId AND T2.ModuleName = TA.ModuleName AND T2.ProductId = TA.ProductId

    LEFT JOIN #T3 T3 ON T3.KDOrderInfoId = TA.KDOrderInfoId AND T3.ProductId = TA.ProductId

    LEFT JOIN #T4 T4 ON T4.KDOrderInfoId = TA.KDOrderInfoId AND T4.ProductId = TA.ProductId

    ORDER BY TA.IsIgnore, TA.ModuleName;



    DROP TABLE #KDOrderItem,#T2,#T3,#T4;



    RETURN 0;

	

END;

