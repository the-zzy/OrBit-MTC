 
CREATE PROCEDURE [dbo].[Factory_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT     
		FactoryId, 
		FactoryName+ CASE ISNULL(FactoryDescription,'') WHEN '' THEN '' ELSE ' '+FactoryDescription END  AS FactoryName
	FROM         dbo.Factory
	Order by FactoryName

	return 0
END
 




