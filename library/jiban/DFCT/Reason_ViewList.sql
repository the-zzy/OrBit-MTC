

-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.09.20>
-- Description:	<获取修改重量原因>
-- Rev:1.00
-- =============================================
create PROCEDURE [dbo].[Reason_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT  UserCodeId as ReasonId,UserCodeName+' '+UserCodeDescription as   Reason 
		
	FROM     UserCode 
	Where ParentUserCodeId='URC1000000F5'

	return 0
END


