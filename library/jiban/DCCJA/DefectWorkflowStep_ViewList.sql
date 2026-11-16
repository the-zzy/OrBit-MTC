
-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.05.09>
-- Description:	<获取不良节点列表>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[DefectWorkflowStep_ViewList]
    @QueryParameter NVARCHAR(100) = ''
AS
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        DECLARE @WorkflowId CHAR(12);
        DECLARE @WorkflowStepId CHAR(12);

        SET @WorkflowId = '';
        SET @WorkflowStepId = '';

	--if ISNULL(@QueryParameter,'')=''
	--	return 0

        --SELECT TOP 1
        --        @WorkflowId = WorkflowId
        --FROM    Lot(NOLOCK)
        --WHERE   LotSN = @QueryParameter
        --       -- AND ISNULL(LotSN, '') <> '';

        SELECT  WorkflowStep.WorkflowStepId AS DefectWorkflowStepId,
                WorkflowStep.WorkflowStepName AS DefectWorkflowStepName
        FROM    WorkflowStep(NOLOCK)
        INNER JOIN Specification(NOLOCK) ON Specification.SpecificationId = WorkflowStep.SpecificationId
        WHERE   WorkflowStep.WorkflowId =@QueryParameter
                AND Specification.IsDefectStep = 1;

        RETURN 0;

    END;
	