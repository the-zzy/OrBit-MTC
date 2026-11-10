

-- =============================================

-- Author:		<1002873>

-- Create date: <01 13 2025  3:20PM>

-- Description:	为BOMBindRalation创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[BOMBindRalationMainView]

@I_PKId char(12) =''				--主键

--以上变量为系统服务固定接口参数，必须在每一个MainView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--执行MainView,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解MainView过程如何编写，请参考我们提供的示例_SampleProjectMainView



	SELECT a.BOMBindRalationId, b.prdname AS ProductName, b.ProductDescription

	FROM  BOMBindRalation a

	INNER JOIN Product b ON a.ProductId = b.ProductId

	where a.BOMBindRalationId=@I_PKId

	

	return 0



END