
-- =============================================
-- Author:		<chensengang>
-- Create date: <10 31 2021  5:05PM>
-- Description:	为ContainerItem创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[ContainerItemTreeView]
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
        SELECT  a.ContainerItemId, a.ContainerInfoId, c.OrderName, d.prdname AS ProductName, d.ProductDescription,
                a.RealQty
        FROM    dbo.ContainerItem a
        LEFT JOIN dbo.KDOrderInfo c ON c.KDOrderInfoId = a.KDOrderInfoId
        LEFT JOIN dbo.Product d ON d.ProductId = a.ProductId
        WHERE   a.ContainerItemId = @I_PKId;

        RETURN 0;
    END;

    DECLARE @KDOrderInfoId CHAR(12) = '';

    DECLARE @Container VARCHAR(30) = '';
    DECLARE @SONameStr NVARCHAR(1000) = '';
    DECLARE @StowageType NVARCHAR(10) = '';

    DECLARE @TempContainerItem TABLE
        (
          KdOrderInfoId CHAR(12) DEFAULT '' ,
          KKOrderInfoId CHAR(12) DEFAULT '' ,
          ProductId CHAR(12) DEFAULT '' ,
          RealQty DECIMAL(18, 4) DEFAULT 0
        );

    DECLARE @TempSOName TABLE
        (
          SOName NVARCHAR(50) DEFAULT ''
        );

    SELECT  @Container = ContainerSN, @SONameStr = SONameStr, @StowageType = StowageType
    FROM    dbo.ContainerInfo
    WHERE   ContainerInfoId = @I_ParentPKId;

    IF @StowageType = '整机'
    BEGIN
        IF ISNULL(@Container, '') <> ''
        BEGIN
            INSERT  INTO @TempContainerItem ( KdOrderInfoId, ProductId, RealQty )
                    SELECT  c.OrderFieldSettingId, a.ProductId, SUM(a.LotQty)
                    FROM    dbo.WW_FGInventory a
                    INNER JOIN dbo.Lot b ON b.LotId = a.LotId
                    INNER JOIN dbo.OrderFieldSetting c ON c.OrderName = b.OrderName
                    WHERE   CartonNum = @Container AND IsCancel = 0
                    GROUP BY c.OrderFieldSettingId, a.ProductId;
        END;

		--向前台返回所有的数据时执行
        SELECT  a.ContainerItemId, IIF(a.RealQty <> ISNULL(c.RealQty, 0), '未完成', '已完成') AS '状态', b.OrderName,
                b.ProductName, b.ProductName AS ProductName, d.ProductDescription, a.RealQty AS '配载数量', c.RealQty AS '已装柜数量',
                IIF(a.RealQty <> ISNULL(c.RealQty, 0), '[RowColor:Y4Z]', '[RowColor:YDZ]') AS ColorControlId
        FROM    dbo.ContainerItem a
        LEFT JOIN dbo.OrderFieldSetting b ON b.OrderFieldSettingId = a.KDOrderInfoId
        LEFT JOIN @TempContainerItem c ON c.KdOrderInfoId = a.KDOrderInfoId AND c.ProductId = a.ProductId
		LEFT JOIN dbo.Product d ON d.ProductId = a.ProductId
		LEFT JOIN dbo.ProductRoot e ON e.DefaultProductId = d.ProductId
        WHERE   a.ContainerInfoId = @I_ParentPKId AND a.IsCancel = 0
        ORDER BY b.OrderName, b.ProductName;

        RETURN 0;
    END;
    ELSE
    BEGIN

        IF ISNULL(@Container, '') <> ''
        BEGIN
		
            INSERT  INTO @TempSOName ( SOName )
                    SELECT DISTINCT
                            parameter_Value
                    FROM    dbo.ConvertParameterToTable(@SONameStr, ',')
                    WHERE   parameter_Value <> '';

            INSERT  INTO @TempContainerItem ( KdOrderInfoId, ProductId, RealQty )
                    SELECT  c.KDOrderInfoId, d.ProductId, SUM(d.RealQty)
                    FROM    @TempSOName a
                    INNER JOIN dbo.KDOrderInfo b ON b.SOName = a.SOName
                    INNER JOIN dbo.KDBoxInfo c ON c.KDOrderInfoId = b.KDOrderInfoId
                    INNER JOIN dbo.KDBoxItem d ON d.KDBoxInfoId = c.KDBoxInfoId
                    WHERE   c.Container = @Container AND c.IsCancel = 0 AND d.IsCancel = 0
                    GROUP BY c.KDOrderInfoId, d.ProductId;

            UPDATE  a
            SET     a.KdOrderInfoId = c.KDOrderInfoId
            FROM    @TempContainerItem a
            INNER JOIN dbo.KDOrderInfo b ON b.KDOrderInfoId = a.KdOrderInfoId
            INNER JOIN dbo.KDOrderInfo c ON c.OrderName = 'SL' + RIGHT(b.OrderName, 12)
            WHERE   b.OrderName LIKE 'ZZ%';

            INSERT  INTO @TempContainerItem ( KdOrderInfoId, KKOrderInfoId, ProductId, RealQty )
                    SELECT  KdOrderInfoId, KdOrderInfoId, ProductId, SUM(RealQty)
                    FROM    @TempContainerItem
                    GROUP BY KdOrderInfoId, ProductId;

            DELETE  FROM @TempContainerItem
            WHERE   KKOrderInfoId = '';

			--外购解码板
            IF EXISTS ( SELECT  1
                        FROM    @TempContainerItem a
                        INNER JOIN dbo.KDOrderInfo b ON b.KDOrderInfoId = a.KdOrderInfoId
                        WHERE   b.OrderName LIKE 'SL%' AND b.ProductCode LIKE '515%' )
            BEGIN
                DECLARE cursor1 CURSOR
                FOR
                SELECT DISTINCT
                        b.KDOrderInfoId
                FROM    @TempContainerItem a
                INNER JOIN dbo.KDOrderInfo b ON b.KDOrderInfoId = a.KdOrderInfoId
                WHERE   b.OrderName LIKE 'SL%' AND b.ProductCode LIKE '515%';
                OPEN cursor1;
                FETCH NEXT FROM cursor1
				INTO @KDOrderInfoId;
                WHILE @@FETCH_STATUS = 0
                BEGIN 
				
                    DELETE  FROM @TempContainerItem
                    WHERE   KdOrderInfoId = @KDOrderInfoId;

                    IF NOT EXISTS ( SELECT  1
                                    FROM    dbo.KDBoxInfo
                                    WHERE   KDOrderInfoId = @KDOrderInfoId AND DeliveryName = '' AND IsCancel = 0 )
                    BEGIN
                        INSERT  INTO @TempContainerItem ( KdOrderInfoId, KKOrderInfoId, ProductId, RealQty )
                                SELECT  KDOrderInfoId, KDOrderInfoId, ProductId, OrderQty
                                FROM    dbo.KDOrderInfo
                                WHERE   KDOrderInfoId = @KDOrderInfoId;
                    END;
	
                    FETCH NEXT FROM cursor1 
					INTO @KDOrderInfoId;
                END;
                CLOSE cursor1;
                DEALLOCATE cursor1;
            END;
        END;

		--向前台返回所有的数据时执行
        SELECT  a.ContainerItemId, IIF(a.RealQty <> ISNULL(e.RealQty, 0), '未完成', '已完成') AS '状态', c.OrderName,
                c.ProductCode, d.prdname AS ProductName,f.ProductWeight AS 物料单重, d.ProductDescription, a.RealQty AS '配载数量', e.RealQty AS '已装柜数量',a.CreateDate,
                IIF(a.RealQty <> ISNULL(e.RealQty, 0), '[RowColor:Y4Z]', '[RowColor:YDZ]') AS ColorControlId
        FROM    dbo.ContainerItem a
        LEFT JOIN dbo.KDOrderInfo c ON c.KDOrderInfoId = a.KDOrderInfoId
        LEFT JOIN dbo.Product d WITH ( NOLOCK ) ON d.ProductId = a.ProductId
			LEFT JOIN dbo.ProductRoot f ON f.DefaultProductId = d.ProductId
        LEFT JOIN @TempContainerItem e ON e.KdOrderInfoId = a.KDOrderInfoId AND e.ProductId = a.ProductId
        WHERE   a.ContainerInfoId = @I_ParentPKId AND a.IsCancel = 0
        ORDER BY c.OrderName, d.prdname,状态;

        RETURN 0;
    END; 

    RETURN 0;
END;


