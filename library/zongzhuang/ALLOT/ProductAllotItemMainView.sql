-- =============================================

-- Author:		<neil>

-- Create date: <04  5 2012  1:57PM>

-- Description:	为ProductAllotItem创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[ProductAllotItemMainView]

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

                a.ProductId,

                c.ProductName,

                b.ProductDescription,

                ItemQty,

				a.FromWareHouseId ,

				FromWarehouse.WorkcenterName AS FromWareHouseName ,

				a.ToWareHouseId ,

				ToWarehouse.WorkcenterName AS ToWarehouseName

			FROM       ProductAllotItem as a  

			LEFT JOIN Product as b on a.ProductId = b.ProductId 

			LEFT JOIN ProductRoot as c on b.ProductId = c.DefaultProductId

			LEFT JOIN dbo.Workcenter AS FromWarehouse ON FromWarehouse.WorkcenterId = a.FromWareHouseId

			LEFT JOIN dbo.Workcenter AS ToWarehouse ON ToWarehouse.WorkcenterId = a.ToWareHouseId

			where ProductAllotItemId=@I_PKId

			return 0



END





