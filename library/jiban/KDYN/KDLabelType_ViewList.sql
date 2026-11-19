
-- =============================================
-- Author:		<OrBit Team benson>
-- Create date: <2016.10.21>
-- Description:	<散件标签类别清单>
-- Rev:1.00
-- =============================================
Create PROCEDURE [dbo].[KDLabelType_ViewList]
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    select	
		KDLabelType.KDLabelTypeId as LabelTypeId,
		KDLabelType.LabelType
	from KDLabelType 
	order by LabelType

	return 0
END




