
-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.09.09>
-- Description:	<获取订单列表>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[OrderNameByFGWeight_ViewList]
    @QueryParameter NVARCHAR(100) = ''
AS
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        SELECT DISTINCT
                OrderFieldSetting.OrderFieldSettingId, OrderFieldSetting.OrderName, MO.MOName, ProductRoot.ProductName,
                ISNULL(OrderFieldSetting.BoxLotQty, 0) AS BoxLotQty, Label.LabelName, Label.LabelFile,
                ISNULL(OrderFieldSetting.IsFGWeight, 'N') AS IsFGWeight, OrderFieldSetting.FGWeightMin AS MoFGWeightMin,
                OrderFieldSetting.FGWeightMax AS MoFGWeightMax
        FROM    OrderFieldSetting(NOLOCK)
        LEFT JOIN MO(NOLOCK) ON MO.MOId = OrderFieldSetting.MOId
        LEFT JOIN Product(NOLOCK) ON Product.ProductId = MO.ProductId
        LEFT JOIN ProductRoot(NOLOCK) ON ProductRoot.ProductRootId = Product.ProductRootId
        LEFT JOIN Label(NOLOCK) ON Label.LabelId = OrderFieldSetting.BoxSNLabelId
        WHERE   OrderFieldSetting.IsClose = 0
        ORDER BY OrderFieldSetting.OrderName;

        RETURN 0;

    END;


