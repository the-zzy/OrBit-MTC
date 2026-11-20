



-- =============================================
-- Author:		<OrBit Team>
-- Create date: <2008.8.8>
-- Description:	<获取SOP主显示字段>
-- =============================================
CREATE PROCEDURE [dbo].[SOPMainView] 
@I_PKId char(12)=''					--主键
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @SOPUrl nvarchar(100)=''
	--declare @SOPUrl2 nvarchar(100)=''
	declare @SOPFtpFile nvarchar(100)=''
	--declare @SOPFtpFile2 nvarchar(100)=''

	SELECT    @SOPUrl=dbo.SOP.SOPUrl,@SOPFtpFile=dbo.SOP.SOPUrl
	FROM         dbo.SOP INNER JOIN
						  dbo.SOPRoot ON dbo.SOP.SOPRootId = dbo.SOPRoot.SOPRootId
	WHERE     (dbo.SOP.SOPId = @I_PKId)

	--	SELECT    @SOPUrl2=dbo.SOP.SOPUrl2,@SOPFtpFile2=dbo.SOP.SOPUrl2
	--FROM         dbo.SOP INNER JOIN
	--					  dbo.SOPRoot ON dbo.SOP.SOPRootId = dbo.SOPRoot.SOPRootId
	--WHERE     (dbo.SOP.SOPId = @I_PKId)

	if SUBSTRING(@SOPUrl,1,4)='FTP1'
	begin
		set @SOPUrl=''
	end
	else
	begin
	    set @SOPFtpFile=''
	end

	--if SUBSTRING(@SOPUrl2,1,4)='FTP1'
	--begin
	--	set @SOPUrl2=''
	--end
	--else
	--begin
	--    set @SOPFtpFile2=''
	--end
	


	SELECT     dbo.SOPRoot.SOPName, dbo.SOP.SOPRootId, dbo.SOP.SOPRevision, dbo.SOP.SOPDescription, 
		@SOPUrl as SOPUrl, @SOPFtpFile as SOPFtpFile,'' as SOPUrl2, '' as SOPFtpFile2, 
		dbo.SOP.IsActivity, 
						  dbo.SOP.IsDefaultSOP,dbo.SOP.IsShowWindow,ModifyDate
	FROM         dbo.SOP INNER JOIN
						  dbo.SOPRoot ON dbo.SOP.SOPRootId = dbo.SOPRoot.SOPRootId
	WHERE     (dbo.SOP.SOPId = @I_PKId)



END




