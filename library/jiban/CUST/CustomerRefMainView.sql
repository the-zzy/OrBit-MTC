

-- =============================================

-- Author:		<yf1002>

-- Create date: <10  8 2018  6:39PM>

-- Description:	为CustomerRef创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[CustomerRefMainView]

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

               [CustomerRefID]

      ,[Customerid]

      ,[Customercode]

      ,[CustomerName]

      ,[CustomerItem]

      ,[CustomerItemNo]

      ,[CompanyModel]

      ,[color]

      ,[OC_PN]

      ,[O_C_Glass]

      ,[O_Csize]

      ,[Remark]

      ,[MainPN]

      ,[LCMPN]

      ,[SKU]

      ,[OriginalPN]

      ,[SellCode]

      ,[SellID]

	  ,[IR_PN]

			FROM        CustomerRef

			where CustomerRefID = @I_PKId

			return 0



END



---ALTER TABLE CustomerRef ADD IR_CN VARCHAR(20) DEFAULT ''