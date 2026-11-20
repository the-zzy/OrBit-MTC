-- =============================================
-- Author:		<LZH>
-- Create date: <2024.06.01>
-- Description:	<获取SKD装箱标签模板>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[SKDBoxLabel_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT LabelName AS BoxLabelName
	FROM Label
	WHERE LabelType = 'SKD'
	AND IsActivity = 1


	RETURN 0;

END







