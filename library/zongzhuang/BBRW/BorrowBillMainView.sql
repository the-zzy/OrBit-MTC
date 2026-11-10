

-- =============================================

-- Author:		<yf1002>

-- Create date: <03 16 2018  5:29PM>

-- Description:	为BorrowBill创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[BorrowBillMainView]

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

                OAId,

                CASE WHEN BillType = 1 THEN '实验室借机'

                ELSE '产线借机' end AS BillType,

                --BillType,

                FactoryId,

                FactoryName,

                DepartId,

                DepartName,

                ApplyDate,

                SAPBIll,

                SAPMessage,

                IsCancel,

                CreaDate,

                MoveReason

			FROM        BorrowBill

			where BorrowBillId=@I_PKId

			return 0



END