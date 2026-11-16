


-- =============================================
-- Author:		<OBit Team  H.R.>
-- Create date: <2008.8.8>
-- Description:	<获取Shift清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[Shift_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT     ShiftId, ShiftName
	FROM         Shift
	ORDER BY ShiftName

END





