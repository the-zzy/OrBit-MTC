

-- =============================================
-- Author:		<administrator>
-- Create date: <05 29 2009 11:07AM>
-- Description:	为Workflow创建主视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[WorkflowMainView]
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
		dbo.WorkflowRoot.WorkflowName, 
		dbo.Workflow.WorkflowRootId, 
		dbo.Workflow.WorkflowRevision, 
		dbo.Workflow.WorkflowType,
		dbo.Workflow.WorkflowDescription, 
		dbo.Workflow.IsActivity, 
		dbo.Workflow.IsDefaultWorkflow,
		dbo.Workflow.IsMetadataFlow, 
		dbo.Workflow.ModifyDate, 
		dbo.Workflow.CreateDate,
		dbo.Workflow.CreateUserId,
		SysUser.UserName as WorkflowCreateUserName
	FROM  dbo.Workflow 
	INNER JOIN dbo.WorkflowRoot ON dbo.Workflow.WorkflowRootId = dbo.WorkflowRoot.WorkflowRootId
	left join SysUser on Workflow.CreateUserId = SysUser.UserId
	WHERE     (dbo.Workflow.WorkflowId = @I_PKId)

END


