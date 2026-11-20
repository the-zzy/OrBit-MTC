
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016 12:03PM>
-- Description:	为KDOrderInfo创建主视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDOrderInfoMainView]
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
        KDOrderInfo.OrderName,
		KDOrderInfo.SOName,
		KDOrderInfo.IsSplitBatch,
		Product.ProductDescription as OrderDescription, 
		KDOrderInfo.ProductId,
		KDOrderInfo.ProductCode as ProductName, 
		KDOrderInfo.OrderQty,
        KDOrderInfo.CustomerName,
        KDOrderInfo.CustomerModel,      
		KDOrderInfo.RollingPlan,
        KDOrderInfo.OrderDate,
		KDOrderInfo.Brand,
		KDOrderInfo.Panel,
		KDOrderInfo.SKD,
		KDOrderInfo.SupplierCode,
		KDOrderInfo.ProjectNo,
		KDOrderInfo.PoNo,
		KDOrderInfo.LotNo,
		KDOrderInfo.MadeCountry,
		KDOrderInfo.Country,
		KDOrderInfo.KDLabelTypeId as LabelTypeId,
		KDLabelType.LabelType,
		KDOrderInfo.WorkflowId,
		WorkflowRoot.WorkflowName,
		SysUser.UserName as CreateUserName,
		KDOrderInfo.CreateDate,
		KDOrderInfo.CustomerAddress,
		KDOrderInfo.LMNYPCustomerModel,
		KDOrderInfo.LMNYPPINO,
		KDOrderInfo.LMNYSCustomerModel,
		KDOrderInfo.LMNYSPINO,
		KDOrderInfo.BoxLabelName,
		KDOrderInfo.CustomerField1,
		KDOrderInfo.CustomerField2,
		KDOrderInfo.CustomerField3,
		KDOrderInfo.CustomerField4
	FROM        KDOrderInfo
	left join SysUser on SysUser.UserId=KDOrderInfo.CreateUserId
	left join KDLabelType on KDLabelType.KDLabelTypeId=KDOrderInfo.KDLabelTypeId
	left join Workflow on Workflow.WorkflowId=KDOrderInfo.WorkflowId
	left join WorkflowRoot on WorkflowRoot.WorkflowRootId=Workflow.WorkflowRootId
	left join Product on Product.ProductId=KDOrderInfo.ProductId
	left join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
	where KDOrderInfoId=@I_PKId
	return 0

END
