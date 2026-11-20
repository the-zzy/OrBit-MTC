

-- =============================================
-- Author:		<OBit Team benson>
-- Create date: <2016.7.01>
-- Description:	<散件箱号类别>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[KDBoxType_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	SELECT '' AS KDBoxTypeId,'' AS BoxType,'' AS BoxTypeDesc
	UNION ALL
	SELECT KDBoxTypeId, BoxType,BoxTypeDesc from KDBoxType order by BoxType

	return 0

END



