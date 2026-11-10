
-- =============================================
-- Author:		<OBit Team  Henry>
-- Create date: <2009.4.21>
-- Description:	<为获取Workflow清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[Workflow_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	select '' as WorkflowId,'' as WorkflowName,'' as WorkflowDescription
	union all
	SELECT TOP (100) PERCENT 
		Workflow.WorkflowId, 
		WorkflowRoot.WorkflowName + ' ' + Workflow.WorkflowRevision AS WorkflowName, 
		Workflow.WorkflowDescription
	FROM         Workflow INNER JOIN
						  WorkflowRoot ON Workflow.WorkflowRootId = WorkflowRoot.WorkflowRootId
	WHERE     (Workflow.IsActivity = 1) and (Workflow.IsMetadataFlow is null or Workflow.IsMetadataFlow=0)
	ORDER BY WorkflowName
END





