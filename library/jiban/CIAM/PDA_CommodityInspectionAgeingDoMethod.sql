

-- =============================================
-- Author:		<1001815>
-- Create date: <2019.01.27>
-- Description: 商检老化
-- =============================================
CREATE PROCEDURE [dbo].[PDA_CommodityInspectionAgeingDoMethod]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',			--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
@SerialNumber nvarchar(50)=''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @AgeingTime DATETIME

	-- 如果该流水号不存在，则报错
	IF NOT EXISTS(SELECT 1 FROM CommodityInspectionTest WHERE SerialNumber = @SerialNumber AND IsCancel = 0)
	BEGIN
		set @I_ReturnMessage='ServerMessage:流水号['+ @SerialNumber +']在系统中不存在，请检查系统是否在维护中！'
		set @I_ExceptionFieldName='SerialNumber'
		return -1
	END

	select top 1 @AgeingTime=CreateDate from CommodityInspectionTest where SerialNumber=@SerialNumber order by CreateDate desc
	IF DATEDIFF(HOUR,@AgeingTime,GETDATE()) < 4
	begin
		set @I_ReturnMessage='ServerMessage:流水号['+ @SerialNumber +']在老化时间内，无法扫描！'
		set @I_ExceptionFieldName='SerialNumber'
		return -1                                                         
	end
	else
	begin
		set @I_ReturnMessage='ServerMessage:流水号['+ @SerialNumber +']扫描成功！'
		set @I_ExceptionFieldName='SerialNumber'
		if exists(select 1 from CommodityInspectionAgeing where SerialNumber=@SerialNumber and IsCancel=0)
		begin
			update CommodityInspectionAgeing set IsCancel = 1 where SerialNumber=@SerialNumber and IsCancel=0
			insert into CommodityInspectionAgeing(SerialNumber,AgeingTime) values(@SerialNumber,getdate())
		end
		else
		begin 
			insert into CommodityInspectionAgeing(SerialNumber,AgeingTime) values(@SerialNumber,getdate())
		end
	end
	return 0
	
END
