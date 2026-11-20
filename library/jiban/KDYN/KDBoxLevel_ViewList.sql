

-- =============================================
-- Author:		<OBit Team benson>
-- Create date: <2016.7.01>
-- Description:	<散件箱号层级>
-- Rev:1.00
-- =============================================
Create PROCEDURE [dbo].[BoxLevel_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	select 'A0' as BoxLevel
	union all 
	
	select 'A2' as BoxLevel
	union all 
	
	select 'A4' as BoxLevel

	return 0

END


