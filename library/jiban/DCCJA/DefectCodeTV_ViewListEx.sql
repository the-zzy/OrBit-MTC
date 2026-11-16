

-- =============================================
-- Author:		<OrBit Team Phoenix>
-- Create date: <2016.9.23>
-- Description:	<根据@I_OrBitUserId配置USERCODE列表>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[DefectCodeTV_ViewListEx] 
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId char(12)='',			--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名

@QueryParameter nvarchar(100)='' 
--以上个变量为系统服务固定接口参数，必须在每一个ViewListEx过程中实现.>
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    ----根据用户账号选择不同的不良代码--
   
    declare @DivisionId char(12)=''
	select @DivisionId=DivisionId from SysUser where userid=@I_OrBitUserId

	if isnull(@DivisionId,'')='DIV10000000P'		--AV总装不良代码
	begin
		SELECT     
		DefectCodeId, 
		DefectCodeName as DefectCode,
		DefectCodeDescription as DefectCodeDescription,
		DefectTypeId
		FROM DefectCode 
		where DefectTypeId in (select UserCodeId from UserCode where ParentUserCodeId='URC1000000SG') and Isactivity=1
		order by DefectCodeName		
		return	
	end
	if isnull(@DivisionId,'')='DIV100000005'		--TV总装不良代码
	begin
		SELECT     
		DefectCodeId, 
		DefectCodeName as DefectCode,
		DefectCodeDescription as DefectCodeDescription,
		DefectTypeId
		FROM DefectCode 
		where DefectTypeId in (select UserCodeId from UserCode where ParentUserCodeId='URC1000000SH') and Isactivity=1
		order by DefectCodeName		
		return	
	end
	if isnull(@DivisionId,'')='DIV10000000L'		--基板总装不良代码
	begin
		SELECT     
		DefectCodeId, 
		DefectCodeName as DefectCode,DefectCodeName as ReCheckeCode,
		DefectCodeDescription as DefectCodeDescription,
		DefectTypeId
		FROM DefectCode 
		where DefectTypeId in (select UserCodeId from UserCode where ParentUserCodeId='URC1000000OD') and Isactivity=1
		order by DefectCodeName		
		return	
	end
												--全部不良代码
	SELECT     
		DefectCodeId, 
		DefectCodeName as DefectCode,
		DefectCodeDescription as DefectCodeDescription,
		DefectTypeId
		FROM DefectCode where  Isactivity=1
		ORDER BY DefectCodeName 
END


