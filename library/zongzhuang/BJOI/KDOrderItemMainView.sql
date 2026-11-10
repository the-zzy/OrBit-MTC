

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016  1:09PM>

-- Description:	为KDOrderModuleItem创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDOrderItemMainView]

@I_PKId char(12) =''				--主键

--以上变量为系统服务固定接口参数，必须在每一个MainView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--执行MainView,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解MainView过程如何编写，请参考我们提供的示例_SampleProjectMainView



	SELECT   

		KDOrderItem.KDOrderItemId,

		KDOrderItem.UOMId,

		KDOrderItem.CustomerNumber,

		KDOrderItem.ModuleName,

		KDOrderItem.EnglishDescription,

		KDOrderItem.ProductId,

		[dbo].[RemoveZero](ProductRoot.ProductName) as ProductName,

		ProductRoot.ProductWeight,

		KDOrderItem.FieldsA,

		KDOrderItem.BOMQtyRequired,

		KDOrderItem.QtyPack,

		KDOrderItem.ItemQtyRequired,

		KDOrderItem.SingleWeight,

		LineSequence

	FROM   KDOrderItem

	inner join Product on Product.ProductId=KDOrderItem.ProductId

	inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId

	where KDOrderItem.KDOrderItemId=@I_PKId 



	return 0



END

